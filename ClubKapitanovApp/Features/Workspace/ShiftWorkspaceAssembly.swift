import UIKit

/// Сборщик основного workspace смены.
///
/// Модуль получает уже открытую `Shift`, подтягивает каталоги сувенирки и штрафов
/// для ее точки, затем собирает VIP-связки экрана.
enum ShiftWorkspaceAssembly {
    static func makeModule(shift: Shift, container: AppDIContainer) -> UIViewController {
        let presenter = ShiftWorkspacePresenter(
            contentFactory: container.makeShiftWorkspaceContentFactory()
        )
        let router = ShiftWorkspaceRouter(container: container)
        let interactor = ShiftWorkspaceInteractor(
            shift: shift,
            rentalTypes: container.catalogRepository.getRentalTypes(pointID: shift.point.id),
            souvenirProducts: container.catalogRepository.getSouvenirProducts(pointID: shift.point.id),
            fineTemplates: container.catalogRepository.getFineTemplates(pointID: shift.point.id),
            batteryItems: container.catalogRepository.getBatteryItems(pointID: shift.point.id),
            authRepository: container.authRepository,
            shiftRepository: container.shiftRepository,
            reportRepository: container.reportRepository,
            shiftReportWriter: container.shiftReportWriter,
            connectivityChecker: container.connectivityChecker,
            buildShiftCloseReportUseCase: container.makeBuildShiftCloseReportUseCase(),
            dateProvider: container.dateProvider,
            presenter: presenter,
            router: router
        )
        let viewController = ShiftWorkspaceViewController(
            interactor: interactor
        )

        presenter.viewController = viewController
        router.viewController = viewController

        return viewController
    }
}
