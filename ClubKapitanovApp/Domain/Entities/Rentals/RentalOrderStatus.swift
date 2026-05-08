import Foundation

/// Жизненный цикл заказа проката.
///
/// Active-заказы видны как текущие и считаются по таймеру `expectedEndAt`.
/// Completed участвуют в выручке и количестве сдач. Canceled сохраняются для истории,
/// но не должны попадать в итоговую выручку как завершенные.
enum RentalOrderStatus: String, Codable, Sendable, CaseIterable {
    case active
    case completed
    case canceled
}
