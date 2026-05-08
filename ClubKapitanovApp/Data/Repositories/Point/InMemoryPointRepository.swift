import Foundation

/// Временная in-memory реализация `PointRepository`.
///
/// Здесь сосредоточено правило видимости точек: staff видит все активные точки,
/// manager только свою, admin технически видит все, но рабочий app-flow админов
/// отсекает раньше на Login-экране.
final class InMemoryPointRepository: PointRepository {
    private let points: [Point]

    init(points: [Point] = InMemoryFixtures.points) {
        self.points = points
    }

    func getAvailablePoints(for user: User) -> [Point] {
        // Неактивные точки скрываются из выбора, но сами записи можно оставить
        // в хранилище ради истории старых смен и отчетов.
        let activePoints = points.filter(\.isActive)

        switch user.role {
        case .admin, .staff:
            return activePoints
        case .manager:
            guard let managedPointID = user.managedPointID else {
                return []
            }
            return activePoints.filter { $0.id == managedPointID }
        }
    }
}
