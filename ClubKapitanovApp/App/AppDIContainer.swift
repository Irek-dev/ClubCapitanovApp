import Foundation

/// Простейший dependency injection container приложения.
///
/// Он хранит реализации инфраструктурных протоколов и создает use case'ы. Feature-модули
/// получают зависимости через assembly и не создают Data/Core-объекты напрямую.
final class AppDIContainer {
    // MARK: - Repositories

    let authRepository: AuthRepository
    let pointRepository: PointRepository
    let adminPointRepository: AdminPointRepository
    let catalogRepository: CatalogRepository
    let shiftRepository: ShiftRepository
    let reportRepository: ReportRepository
    let adminUserRepository: AdminUserRepository
    let adminPointCatalogRepository: AdminPointCatalogRepository
    let shiftReportWriter: FirebaseShiftReportWriting
    let connectivityChecker: ConnectivityChecking
    let dateProvider: DateProviding

    // MARK: - Init

    init(
        authRepository: AuthRepository? = nil,
        pointRepository: PointRepository? = nil,
        adminPointRepository: AdminPointRepository? = nil,
        catalogRepository: CatalogRepository = FirebaseCatalogRepository(),
        shiftRepository: ShiftRepository = InMemoryShiftRepository(),
        reportRepository: ReportRepository = InMemoryReportRepository(),
        adminUserRepository: AdminUserRepository? = nil,
        adminPointCatalogRepository: AdminPointCatalogRepository = FirebaseAdminPointCatalogRepository(),
        shiftReportWriter: FirebaseShiftReportWriting = FirestoreShiftReportRepository(),
        connectivityChecker: ConnectivityChecking = NetworkConnectivityService(),
        dateProvider: DateProviding = SystemDateProvider()
    ) {
        let firebaseUserRepository: FirebaseUserRepository?
        if authRepository == nil || adminUserRepository == nil {
            firebaseUserRepository = FirebaseUserRepository()
        } else {
            firebaseUserRepository = nil
        }
        let firebasePointRepository: FirebasePointRepository?
        if pointRepository == nil || adminPointRepository == nil {
            firebasePointRepository = FirebasePointRepository()
        } else {
            firebasePointRepository = nil
        }
        let resolvedAuthRepository = authRepository ?? firebaseUserRepository!

        self.authRepository = resolvedAuthRepository
        self.pointRepository = pointRepository ?? firebasePointRepository!
        self.adminPointRepository = adminPointRepository ?? firebasePointRepository!
        self.catalogRepository = catalogRepository
        self.shiftRepository = shiftRepository
        self.reportRepository = reportRepository
        self.adminUserRepository = adminUserRepository
            ?? (resolvedAuthRepository as? AdminUserRepository)
            ?? firebaseUserRepository!
        self.adminPointCatalogRepository = adminPointCatalogRepository
        self.shiftReportWriter = shiftReportWriter
        self.connectivityChecker = connectivityChecker
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
