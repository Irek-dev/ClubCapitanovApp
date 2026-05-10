import Foundation

/// Простейший dependency injection container приложения.
///
/// Он хранит реализации инфраструктурных протоколов и создает use case'ы. Feature-модули
/// получают зависимости через assembly и не создают Data/Core-объекты напрямую.
final class AppDIContainer {
    // MARK: - Repositories

    let authRepository: AuthRepository
    let pointRepository: PointRepository
    let catalogRepository: CatalogRepository
    let shiftRepository: ShiftRepository
    let reportRepository: ReportRepository
    let dateProvider: DateProviding

    // MARK: - Init

    init(
        authRepository: AuthRepository = FirebaseCachedAuthRepository(),
        pointRepository: PointRepository = InMemoryPointRepository(),
        catalogRepository: CatalogRepository = FirebaseCachedCatalogRepository(),
        shiftRepository: ShiftRepository = InMemoryShiftRepository(),
        reportRepository: ReportRepository = InMemoryReportRepository(),
        dateProvider: DateProviding = SystemDateProvider()
    ) {
        self.authRepository = authRepository
        self.pointRepository = pointRepository
        self.catalogRepository = catalogRepository
        self.shiftRepository = shiftRepository
        self.reportRepository = reportRepository
        self.dateProvider = dateProvider
    }

    // MARK: - Use Cases

    func makeLoginUseCase() -> LoginUseCase {
        LoginUseCase(authRepository: authRepository)
    }

    func makeBuildShiftPayrollSummaryUseCase() -> BuildShiftPayrollSummaryUseCase {
        BuildShiftPayrollSummaryUseCase()
    }

    func makeBuildShiftCloseReportUseCase() -> BuildShiftCloseReportUseCase {
        BuildShiftCloseReportUseCase(
            payrollUseCase: makeBuildShiftPayrollSummaryUseCase()
        )
    }

    func makeShiftWorkspaceContentFactory() -> ShiftWorkspaceContentFactory {
        ShiftWorkspaceContentFactory(
            payrollUseCase: makeBuildShiftPayrollSummaryUseCase(),
            dateProvider: dateProvider
        )
    }
}
