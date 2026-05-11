import Foundation

/// Временная in-memory реализация `AuthRepository`.
///
/// Оставлена как локальная fallback/test-реализация. Основной app flow теперь
/// подключается к Firebase через `FirebaseUserRepository`.
final class InMemoryAuthRepository: AuthRepository {
    // MARK: - Properties

    private var users: [User]

    // MARK: - Init

    init(users: [User] = InMemoryFixtures.users) {
        self.users = users
    }

    // MARK: - AuthRepository

    func getUser(
        pinCode: String,
        completion: @escaping (Result<User?, Error>) -> Void
    ) {
        completion(.success(findUser(pinCode: pinCode)))
    }

    private func findUser(pinCode: String) -> User? {
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
        users.removeAll { $0.id == id }
    }

    private func generateUniquePIN() -> String {
        let usedPINs = Set(users.map(\.pinCode))

        for _ in 0..<10_000 {
            let pin = Int.random(in: 1000...9999)
            let pinText = String(format: "%04d", pin)
            if !usedPINs.contains(pinText) {
                return pinText
            }
        }

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
