import Foundation

/// Абстракция источника пользователей для PIN-входа.
///
/// Feature-слой не знает, откуда берется пользователь: Firebase-реализация читает
/// `pinCodes/{pin}` и затем `users/{userId}`.
protocol AuthRepository: AnyObject {
    func getUser(
        pinCode: String,
        completion: @escaping (Result<User?, Error>) -> Void
    )
}

protocol AuthRepositoryCacheRefreshing {
    func refreshUsers(completion: @escaping () -> Void)
}

protocol AdminUserRepository: AuthRepository {
    var lastLoadError: Error? { get }

    func refreshUsers(completion: @escaping () -> Void)
    func getAllUsers(includeArchived: Bool) -> [User]
    func createUser(
        firstName: String,
        lastName: String,
        role: UserRole,
        completion: @escaping (Result<User, Error>) -> Void
    )
    func updateUser(
        _ user: User,
        completion: @escaping (Result<User, Error>) -> Void
    )
    func deleteUser(
        id: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}
