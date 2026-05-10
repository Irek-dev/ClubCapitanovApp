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

        guard let user = loginUseCase.execute(pinCode: normalizedPIN) else {
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

        guard let user = loginUseCase.execute(pinCode: normalizedPIN), user.role == .admin else {
            presenter.present(
                response: .init(user: nil),
                errorMessage: "PIN не принадлежит администратору."
            )
            return
        }

        presenter.present(response: .init(user: user), errorMessage: nil)
        router.routeToAdminPointSelection(for: user)
    }
}
