import UIKit

/// Сборщик модуля выбора точки.
///
/// Получает пользователя после успешного Login и внедряет общий DI-контейнер, чтобы
/// следующий экран работал с теми же repository instances.
enum PointSelectionAssembly {
    static func makeModule(user: User, container: AppDIContainer) -> UIViewController {
        let presenter = PointSelectionPresenter()
        let router = PointSelectionRouter(container: container)
        let interactor = PointSelectionInteractor(
            user: user,
            pointRepository: container.pointRepository,
            presenter: presenter,
            router: router
        )
        let viewController = PointSelectionViewController(interactor: interactor)

        presenter.viewController = viewController
        router.viewController = viewController

        return viewController
    }
}
