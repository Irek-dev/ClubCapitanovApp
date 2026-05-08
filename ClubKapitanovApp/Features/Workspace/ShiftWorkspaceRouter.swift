import UIKit

/// Навигация из workspace.
///
/// Сейчас единственный выход — закрытие смены и возврат к Login. Router собирает
/// новый Login-модуль и сбрасывает navigation stack, чтобы не вернуться в закрытую смену.
protocol ShiftWorkspaceRoutingLogic: AnyObject {
    func routeToLogin()
}

final class ShiftWorkspaceRouter: ShiftWorkspaceRoutingLogic {
    weak var viewController: UIViewController?
    private let container: AppDIContainer

    init(container: AppDIContainer) {
        self.container = container
    }

    func routeToLogin() {
        let loginViewController = LoginAssembly.makeModule(container: container)
        viewController?.navigationController?.setViewControllers([loginViewController], animated: true)
    }
}
