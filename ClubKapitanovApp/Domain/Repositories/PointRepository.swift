import Foundation

/// Абстракция доступа к рабочим точкам.
///
/// Репозиторий возвращает только те точки, которые пользователь имеет право видеть.
/// Это держит правила доступа вне UIKit-экранов.
protocol PointRepository {
    func getAvailablePoints(for user: User) -> [Point]
}
