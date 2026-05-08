import UIKit

/// Router выбора точки.
///
/// Единственная ответственность — собрать экран открытия смены и положить его в
/// navigation stack. Бизнес-логика выбора точки здесь не живет.
protocol PointSelectionRoutingLogic {
    func routeToOpenShift(point: Point, user: User)
}

final class PointSelectionRouter: PointSelectionRoutingLogic {
    weak var viewController: UIViewController?
    private let container: AppDIContainer

    init(container: AppDIContainer) {
        self.container = container
    }

    func routeToOpenShift(point: Point, user: User) {
        let destination = OpenShiftAssembly.makeModule(
            point: point,
            user: user,
            container: container
        )
        viewController?.navigationController?.pushViewController(destination, animated: true)
    }
}
