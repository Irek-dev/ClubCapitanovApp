import UIKit

/// Сборщик экрана открытия смены.
///
/// Модуль получает `Point` и `User` из предыдущего flow и использует общий
/// `ShiftRepository`, чтобы либо открыть новую смену, либо попасть в уже открытую.
enum OpenShiftAssembly {
    static func makeModule(point: Point, user: User, container: AppDIContainer) -> UIViewController {
        let presenter = OpenShiftPresenter()
        let router = OpenShiftRouter(container: container)
        let interactor = OpenShiftInteractor(
            point: point,
            user: user,
            shiftRepository: container.shiftRepository,
            catalogRepository: container.catalogRepository,
            dateProvider: container.dateProvider,
            presenter: presenter,
            router: router
        )
        let viewController = OpenShiftViewController(interactor: interactor)

        presenter.viewController = viewController
        router.viewController = viewController

        return viewController
    }
}
