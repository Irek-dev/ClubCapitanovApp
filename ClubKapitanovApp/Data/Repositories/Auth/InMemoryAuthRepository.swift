import Foundation

/// Временная in-memory реализация `AuthRepository`.
///
/// Она хранит пользователей в массиве и ищет активного пользователя по PIN. Это
/// достаточно для текущего экрана входа и позволяет не завязывать UI на storage раньше
/// времени.
final class InMemoryAuthRepository: AuthRepository {
    // MARK: - Properties

    private var users: [User]

    // MARK: - Init

    init(users: [User] = InMemoryFixtures.users) {
        self.users = users
    }

    // MARK: - AuthRepository

    func getUser(pinCode: String) -> User? {
        // Заблокированные и архивные пользователи не проходят вход, даже если PIN
        // совпал. Это правило уже проверяется через `User.canSignIn`.
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
        return user
    }

    func updateUser(_ user: User) -> User {
        guard let index = users.firstIndex(where: { $0.id == user.id }) else {
            users.append(user)
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
        return UUID().uuidString.prefix(4).filter(\.isNumber).padding(toLength: 4, withPad: "0", startingAt: 0)
    }
}

extension InMemoryAuthRepository: AuthRepositoryCacheRefreshing {
    func refreshUsers(completion: @escaping () -> Void) {
        completion()
    }
}
