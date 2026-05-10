import Foundation

/// Абстракция источника пользователей для PIN-входа.
///
/// Feature-слой не знает, откуда берется пользователь: сейчас это in-memory список,
/// а позже реализацию можно заменить на постоянное хранилище без изменения Login-flow.
protocol AuthRepository {
    func getUser(pinCode: String) -> User?
    func getAllUsers(includeArchived: Bool) -> [User]
    func createUser(firstName: String, lastName: String, role: UserRole) -> User
    func updateUser(_ user: User) -> User
    func archiveUser(id: UUID)
}

protocol AuthRepositoryCacheRefreshing {
    func refreshUsers(completion: @escaping () -> Void)
}
