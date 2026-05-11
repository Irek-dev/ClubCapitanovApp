import Foundation

/// Business layer открытия смены.
///
/// Здесь реализовано правило: если на точке уже есть открытая смена, не создаем
/// новую, а переходим в существующий workspace. Если нет — собираем новую `Shift`.
protocol OpenShiftBusinessLogic {
    func load()
    func openShift()
}

final class OpenShiftInteractor: OpenShiftBusinessLogic {
    private let point: Point
    private let user: User
    private let shiftRepository: ShiftRepository
    private let catalogRepository: CatalogRepository
    private let dateProvider: DateProviding
    private let presenter: OpenShiftPresentationLogic
    private let router: OpenShiftRoutingLogic
    private var isOpeningShift = false

    init(
        point: Point,
        user: User,
        shiftRepository: ShiftRepository,
        catalogRepository: CatalogRepository,
        dateProvider: DateProviding,
        presenter: OpenShiftPresentationLogic,
        router: OpenShiftRoutingLogic
    ) {
        self.point = point
        self.user = user
        self.shiftRepository = shiftRepository
        self.catalogRepository = catalogRepository
        self.dateProvider = dateProvider
        self.presenter = presenter
        self.router = router
    }

    func load() {
        presenter.present(response: OpenShift.Load.Response(point: point, user: user))
    }

    func openShift() {
        guard !isOpeningShift else {
            return
        }

        isOpeningShift = true
        presenter.present(response: OpenShift.CatalogLoad.Response(isLoading: true))

        guard let refreshingRepository = catalogRepository as? CatalogRepositoryCacheRefreshing else {
            routeToShiftAfterCatalogLoad()
            return
        }

        refreshingRepository.refreshCatalog(pointID: point.id) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                self.routeToShiftAfterCatalogLoad()
            case let .failure(error):
                self.isOpeningShift = false
                self.presenter.present(response: OpenShift.CatalogLoad.Response(isLoading: false))
                self.presenter.present(response: OpenShift.CatalogLoad.ErrorResponse(error: error))
            }
        }
    }

    private func routeToShiftAfterCatalogLoad() {
        isOpeningShift = false
        presenter.present(response: OpenShift.CatalogLoad.Response(isLoading: false))

        // Защита от повторного открытия: repository сам тоже не создаст вторую смену,
        // но ранний check позволяет сразу открыть актуальный workspace.
        if let existingShift = shiftRepository.getOpenShift(pointID: point.id) {
            router.routeToWorkspace(shift: existingShift)
            return
        }

        let shift = shiftRepository.openShift(makeShift())
        router.routeToWorkspace(shift: shift)
    }

    private func makeShift() -> Shift {
        // Новая смена получает одно время открытия для самой смены, первого участника
        // и технического подключения, чтобы стартовый snapshot был консистентным.
        let shiftID = UUID()
        let openedAt = dateProvider.now
        let hostDevice = WorkDevice(
            name: "Общее устройство точки",
            kind: .ipad,
            assignedPointID: point.id,
            isSharedPointDevice: true
        )
        let participant = ShiftParticipant(
            shiftID: shiftID,
            userID: user.id,
            displayNameSnapshot: user.fullName,
            roleSnapshot: user.role,
            joinedAt: openedAt
        )
        let connection = ShiftConnection(
            shiftID: shiftID,
            userID: user.id,
            deviceID: hostDevice.id,
            connectedAt: openedAt,
            mode: .ipadOperator
        )

        return Shift(
            id: shiftID,
            point: point,
            openedByUserID: user.id,
            hostDevice: hostDevice,
            openedAt: openedAt,
            status: .open,
            participants: [participant],
            connections: [connection]
        )
    }
}
