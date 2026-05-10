import UIKit

/// Навигация после успешного PIN-входа.
///
/// Router отделяет переходы от ViewController и Interactor. Interactor решает, что
/// пользователь прошел вход, а Router знает, какой следующий модуль собрать.
protocol LoginRoutingLogic {
    func routeToNextScreen(for user: User)
    func routeToAdminPointSelection(for user: User)
}

final class LoginRouter: LoginRoutingLogic {
    // MARK: - Properties

    weak var viewController: UIViewController?
    private let container: AppDIContainer

    // MARK: - Init

    init(container: AppDIContainer) {
        self.container = container
    }

    // MARK: - LoginRoutingLogic

    func routeToNextScreen(for user: User) {
        // Staff и manager идут в выбор точки. Admin сюда не должен доходить, но case
        // оставлен для защиты от будущих изменений в LoginInteractor.
        switch user.role {
        case .staff, .manager:
            let destination = PointSelectionAssembly.makeModule(user: user, container: container)
            viewController?.navigationController?.pushViewController(destination, animated: true)
        case .admin:
            assertionFailure("Admin users must be handled outside the working app flow.")
        }
    }

    func routeToAdminPointSelection(for user: User) {
        let destination = AdminPointSelectionViewController(
            adminUser: user,
            pointRepository: container.pointRepository,
            container: container
        )
        viewController?.navigationController?.pushViewController(destination, animated: true)
    }
}
