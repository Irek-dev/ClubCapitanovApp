import Foundation

/// Абстракция доступа к рабочим точкам.
///
/// Репозиторий возвращает только те точки, которые пользователь имеет право видеть.
/// Это держит правила доступа вне UIKit-экранов.
protocol PointRepository: AnyObject {
    var lastLoadError: Error? { get }

    func refreshPoints(completion: @escaping () -> Void)
    func getAvailablePoints(for user: User) -> [Point]
}

protocol AdminPointRepository: PointRepository {
    func ensurePointDocument(_ point: Point, completion: @escaping (Result<Void, Error>) -> Void)
}
