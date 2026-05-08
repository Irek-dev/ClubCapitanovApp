import UIKit

/// Router после открытия смены.
///
/// Вместо push он заменяет navigation stack на workspace: после старта смены
/// пользователь не должен возвращаться кнопкой назад к выбору точки/открытию.
protocol OpenShiftRoutingLogic {
    func routeToWorkspace(shift: Shift)
}

final class OpenShiftRouter: OpenShiftRoutingLogic {
    weak var viewController: UIViewController?
    private let container: AppDIContainer

    init(container: AppDIContainer) {
        self.container = container
    }

    func routeToWorkspace(shift: Shift) {
        let workspaceViewController = ShiftWorkspaceAssembly.makeModule(
            shift: shift,
            container: container
        )
        viewController?.navigationController?.setViewControllers([workspaceViewController], animated: true)
    }
}
