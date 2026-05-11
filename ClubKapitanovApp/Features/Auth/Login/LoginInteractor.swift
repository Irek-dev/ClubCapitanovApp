import Foundation

/// Business layer экрана PIN-входа.
///
/// Interactor валидирует PIN, вызывает use case авторизации, отсекает admin-пользователя
/// из рабочего приложения и решает, когда передать пользователя в Router.
protocol LoginBusinessLogic {
    func submit(request: Login.Submit.Request)
    func submitAdmin(request: Login.AdminSubmit.Request)
}

final class LoginInteractor: LoginBusinessLogic {
    private enum Constants {
        static let adminPassword = "123"
    }

    // MARK: - Dependencies

    private let loginUseCase: LoginUseCase
    private let router: LoginRoutingLogic
    private let presenter: LoginPresentationLogic
    private var activeLoginAttemptID: UUID?

    // MARK: - Init

    init(
        loginUseCase: LoginUseCase,
        router: LoginRoutingLogic,
        presenter: LoginPresentationLogic
    ) {
        self.loginUseCase = loginUseCase
        self.router = router
        self.presenter = presenter
    }

    // MARK: - LoginBusinessLogic

    func submit(request: Login.Submit.Request) {
        // View присылает только сырой текст PIN. Interactor нормализует его и первым
        // делом проверяет формат, чтобы не дергать repository с заведомо неверными данными.
        let normalizedPIN = request.pinCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedPIN.count == 4, normalizedPIN.allSatisfy(\.isNumber) else {
            presenter.present(
                response: .init(user: nil),
                errorMessage: "Введите 4-значный PIN."
            )
            return
        }

        let attemptID = UUID()
        activeLoginAttemptID = attemptID

        loginUseCase.execute(pinCode: normalizedPIN) { [weak self] result in
            guard let self, self.activeLoginAttemptID == attemptID else { return }
            self.activeLoginAttemptID = nil

            switch result {
            case let .success(user):
                self.handleRegularLogin(user: user)
            case let .failure(error):
                self.presenter.present(
                    response: .init(user: nil),
                    errorMessage: self.loginErrorMessage(error)
                )
            }
        }
    }

    func submitAdmin(request: Login.AdminSubmit.Request) {
        let normalizedPIN = request.pinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = request.password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedPIN.count == 4, normalizedPIN.allSatisfy(\.isNumber) else {
            presenter.present(
                response: .init(user: nil),
                errorMessage: "Введите 4-значный PIN администратора."
            )
            return
        }

        guard password == Constants.adminPassword else {
            presenter.present(
                response: .init(user: nil),
                errorMessage: "Неверный пароль администратора."
            )
            return
        }

        let attemptID = UUID()
        activeLoginAttemptID = attemptID

        loginUseCase.execute(pinCode: normalizedPIN) { [weak self] result in
            guard let self, self.activeLoginAttemptID == attemptID else { return }
            self.activeLoginAttemptID = nil

            switch result {
            case let .success(user):
                self.handleAdminLogin(user: user)
            case let .failure(error):
                self.presenter.present(
                    response: .init(user: nil),
                    errorMessage: self.loginErrorMessage(error)
                )
            }
        }
    }

    private func handleRegularLogin(user: User?) {
        guard let user else {
            presenter.present(
                response: .init(user: nil),
                errorMessage: "Пользователь с таким PIN не найден."
            )
            return
        }

        guard user.role != .admin else {
            // Admin не должен попадать в iPad-flow: административная часть проекта
            // должна жить отдельно от операционного приложения смены.
            presenter.present(
                response: .init(user: nil),
                errorMessage: "Административный доступ недоступен в рабочем приложении."
            )
            return
        }

        presenter.present(response: .init(user: user), errorMessage: nil)
        router.routeToNextScreen(for: user)
    }

    private func handleAdminLogin(user: User?) {
        guard let user, user.role == .admin else {
            presenter.present(
                response: .init(user: nil),
                errorMessage: "PIN не принадлежит администратору."
            )
            return
        }

        presenter.present(response: .init(user: user), errorMessage: nil)
        router.routeToAdminPointSelection(for: user)
    }

    private func loginErrorMessage(_ error: Error) -> String {
        if let repositoryError = error as? FirebaseUserRepositoryError,
           let description = repositoryError.errorDescription {
            return description
        }

        return "Не удалось проверить PIN. Проверьте интернет и попробуйте снова."
    }
}
