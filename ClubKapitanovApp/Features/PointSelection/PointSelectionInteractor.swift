import Foundation

/// Business layer выбора рабочей точки.
///
/// Interactor запрашивает доступные точки для текущего пользователя, хранит загруженный
/// массив и по индексу выбранной строки передает точку в Router.
protocol PointSelectionBusinessLogic {
    func load()
    func selectPoint(at index: Int)
}

final class PointSelectionInteractor: PointSelectionBusinessLogic {
    private let user: User
    private let pointRepository: PointRepository
    private let presenter: PointSelectionPresentationLogic
    private let router: PointSelectionRoutingLogic
    private var points: [Point] = []

    init(
        user: User,
        pointRepository: PointRepository,
        presenter: PointSelectionPresentationLogic,
        router: PointSelectionRoutingLogic
    ) {
        self.user = user
        self.pointRepository = pointRepository
        self.presenter = presenter
        self.router = router
    }

    func load() {
        // Правила видимости точек находятся в repository. Interactor только сохраняет
        // результат, чтобы потом безопасно обработать выбор по indexPath.
        points = []
        presenter.present(response: .init(user: user, points: points, state: .loading))

        pointRepository.refreshPoints { [weak self] in
            guard let self else { return }

            if self.pointRepository.lastLoadError != nil {
                self.points = []
                self.presenter.present(response: .init(user: self.user, points: [], state: .failed))
                return
            }

            self.points = self.pointRepository.getAvailablePoints(for: self.user)
            self.presenter.present(response: .init(user: self.user, points: self.points, state: .loaded))
        }
    }

    func selectPoint(at index: Int) {
        // UI работает индексами таблицы, поэтому Interactor обязательно проверяет
        // границы массива перед навигацией.
        guard points.indices.contains(index) else {
            return
        }

        router.routeToOpenShift(point: points[index], user: user)
    }
}
