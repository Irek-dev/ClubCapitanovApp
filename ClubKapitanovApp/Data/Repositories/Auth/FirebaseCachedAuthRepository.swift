import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class FirebaseCachedAuthRepository: AuthRepository {
    private var users: [User]
    private var didLoadRemoteUsers = false

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    init(fallbackRepository: AuthRepository = InMemoryAuthRepository()) {
        self.users = fallbackRepository.getAllUsers(includeArchived: true)
    }

    func getUser(pinCode: String) -> User? {
        users.first { $0.pinCode == pinCode && $0.canSignIn }
    }

    func getAllUsers(includeArchived: Bool = false) -> [User] {
        users
            .filter { includeArchived || $0.accountStatus != .archived }
            .sorted { lhs, rhs in
                if lhs.accountStatus != rhs.accountStatus {
                    return lhs.accountStatus == .active
                }

                return lhs.fullName < rhs.fullName
            }
    }

    func createUser(firstName: String, lastName: String, role: UserRole) -> User {
        let user = User(
            pinCode: generateUniquePIN(),
            firstName: firstName,
            lastName: lastName,
            role: role
        )
        users.append(user)
        persistUsers()
        return user
    }

    func updateUser(_ user: User) -> User {
        guard let index = users.firstIndex(where: { $0.id == user.id }) else {
            users.append(user)
            persistUsers()
            return user
        }

        let existingPINOwner = users.first { existingUser in
            existingUser.id != user.id && existingUser.pinCode == user.pinCode
        }
        let normalizedUser = existingPINOwner == nil ? user : User(
            id: user.id,
            pinCode: users[index].pinCode,
            firstName: user.firstName,
            lastName: user.lastName,
            role: user.role,
            accountStatus: user.accountStatus,
            managedPointID: user.managedPointID
        )

        users[index] = normalizedUser
        persistUsers()
        return normalizedUser
    }

    func archiveUser(id: UUID) {
        guard let index = users.firstIndex(where: { $0.id == id }) else {
            return
        }

        let user = users[index]
        users[index] = User(
            id: user.id,
            pinCode: user.pinCode,
            firstName: user.firstName,
            lastName: user.lastName,
            role: user.role,
            accountStatus: .archived,
            managedPointID: user.managedPointID
        )
        persistUsers()
    }

    private func generateUniquePIN() -> String {
        let usedPINs = Set(users.map(\.pinCode))

        for pin in 1000...9999 {
            let pinText = String(format: "%04d", pin)
            if !usedPINs.contains(pinText) {
                return pinText
            }
        }

        assertionFailure("No available 4-digit PIN codes left.")
        return "9999"
    }

    private func applyRemoteUsers(_ remoteUsers: [User]) {
        guard !remoteUsers.isEmpty else { return }
        users = remoteUsers
    }

    private func encodeUser(_ user: User) -> [String: Any] {
        var data: [String: Any] = [
            "id": user.id.uuidString,
            "pinCode": user.pinCode,
            "firstName": user.firstName,
            "lastName": user.lastName,
            "role": user.role.rawValue,
            "accountStatus": user.accountStatus.rawValue
        ]
        if let managedPointID = user.managedPointID {
            data["managedPointID"] = managedPointID.uuidString
        }
        return data
    }

    private func decodeUser(_ data: [String: Any]) -> User? {
        guard
            let idText = data["id"] as? String,
            let id = UUID(uuidString: idText),
            let pinCode = data["pinCode"] as? String,
            let firstName = data["firstName"] as? String,
            let lastName = data["lastName"] as? String,
            let roleText = data["role"] as? String,
            let role = UserRole(rawValue: roleText),
            let statusText = data["accountStatus"] as? String,
            let accountStatus = UserAccountStatus(rawValue: statusText)
        else {
            return nil
        }

        let managedPointID = (data["managedPointID"] as? String).flatMap(UUID.init(uuidString:))
        return User(
            id: id,
            pinCode: pinCode,
            firstName: firstName,
            lastName: lastName,
            role: role,
            accountStatus: accountStatus,
            managedPointID: managedPointID
        )
    }
}

extension FirebaseCachedAuthRepository: AuthRepositoryCacheRefreshing {
    func refreshUsers(completion: @escaping () -> Void) {
        guard !didLoadRemoteUsers else {
            completion()
            return
        }

        #if canImport(FirebaseFirestore)
        usersDocument.getDocument { [weak self] snapshot, _ in
            guard let self else {
                DispatchQueue.main.async { completion() }
                return
            }

            if
                let rawUsers = snapshot?.data()?["users"] as? [[String: Any]],
                !rawUsers.isEmpty
            {
                self.applyRemoteUsers(rawUsers.compactMap(self.decodeUser))
            } else {
                self.persistUsers()
            }

            self.didLoadRemoteUsers = true
            DispatchQueue.main.async { completion() }
        }
        #else
        didLoadRemoteUsers = true
        completion()
        #endif
    }
}

private extension FirebaseCachedAuthRepository {
    #if canImport(FirebaseFirestore)
    var usersDocument: DocumentReference {
        db.collection("adminAuth").document("users")
    }
    #endif

    func persistUsers() {
        #if canImport(FirebaseFirestore)
        usersDocument.setData(["users": users.map(encodeUser)], merge: true)
        #endif
    }
}
