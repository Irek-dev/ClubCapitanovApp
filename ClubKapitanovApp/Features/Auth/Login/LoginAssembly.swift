import UIKit

/// Сборщик Login-модуля.
///
/// Assembly создает ViewController, Interactor, Presenter и Router, связывает их между
/// собой и внедряет зависимости из `AppDIContainer`. Это удерживает wiring вне экрана.
enum LoginAssembly {
    // MARK: - Build

    static func makeModule(container: AppDIContainer) -> UIViewController {
        // Presenter и Router держат weak-ссылку на ViewController, поэтому их можно
        // создать до экрана, а потом связать после init.
        let presenter = LoginPresenter()
        let router = LoginRouter(container: container)
        let interactor = LoginInteractor(
            loginUseCase: container.makeLoginUseCase(),
            router: router,
            presenter: presenter
        )
        let viewController = LoginViewController(interactor: interactor)

        presenter.viewController = viewController
        router.viewController = viewController

        viewController.title = "Вход"
        return viewController
    }
}
