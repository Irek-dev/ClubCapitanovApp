import Foundation

/// Тариф проката, который приходит вместе с каталогом конкретной точки.
///
/// Один тип проката может иметь один общий тариф или несколько разных интервалов:
/// например 20 минут, 40 минут, 1 час. `Features` работают только с этой domain-моделью
/// и не зависят от конкретного источника каталога.
struct RentalTariff: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор тарифа в каталоге.
    let id: UUID
    /// Название для истории и UI: например `20 минут`.
    let title: String
    /// Длительность проката в минутах.
    let durationMinutes: Int
    /// Цена за указанный интервал.
    let price: Money
    /// Порядок показа тарифов, если у типа их несколько.
    let sortOrder: Int
    /// Признак того, что тариф доступен для новых заказов.
    let isActive: Bool

    init(
        id: UUID = UUID(),
        title: String? = nil,
        durationMinutes: Int,
        price: Money,
        sortOrder: Int,
        isActive: Bool = true
    ) {
        self.id = id
        self.title = title ?? "\(durationMinutes) минут"
        self.durationMinutes = durationMinutes
        self.price = price
        self.sortOrder = sortOrder
        self.isActive = isActive
    }
}
