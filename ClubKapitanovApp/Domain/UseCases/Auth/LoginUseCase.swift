import Foundation

/// Use case входа по PIN.
///
/// Сейчас он тонкий и делегирует поиск пользователя в `AuthRepository`, но именно
/// здесь должна появляться доменная логика авторизации, если она станет шире.
struct LoginUseCase {
    // MARK: - Dependencies

    private let authRepository: AuthRepository

    // MARK: - Init

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    // MARK: - Execute

    func execute(
        pinCode: String,
        completion: @escaping (Result<User?, Error>) -> Void
    ) {
        // Use case возвращает domain entity, а не view model: форматирование ошибки
        // и решение о навигации остаются в VIP-слое Login.
        authRepository.getUser(pinCode: pinCode, completion: completion)
    }
}
