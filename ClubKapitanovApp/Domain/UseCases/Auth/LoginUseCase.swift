import Foundation

/// Use case входа по PIN.
///
/// Сейчас он тонкий и просто делегирует поиск пользователю в `AuthRepository`, но
/// именно здесь должна появляться доменная логика авторизации, если она станет шире:
/// блокировки, аудит попыток входа, ограничения по устройству или точке.
struct LoginUseCase {
    // MARK: - Dependencies

    private let authRepository: AuthRepository

    // MARK: - Init

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    // MARK: - Execute

    func execute(pinCode: String) -> User? {
        // Use case возвращает domain entity, а не view model: форматирование ошибки
        // и решение о навигации остаются в VIP-слое Login.
        authRepository.getUser(pinCode: pinCode)
    }
}
