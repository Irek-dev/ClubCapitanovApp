import Foundation

/// Временная in-memory реализация `AuthRepository`.
///
/// Она хранит пользователей в массиве и ищет активного пользователя по PIN. Это
/// достаточно для текущего экрана входа и позволяет не завязывать UI на storage раньше
/// времени.
struct InMemoryAuthRepository: AuthRepository {
    // MARK: - Properties

    private let users: [User]

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
}
