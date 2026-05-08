import Foundation

/// Шаблон штрафа из каталога точки.
///
/// Шаблон нужен только для выбора в интерфейсе. Когда штраф фактически начислен,
/// создается `FineRecord`, который сохраняет snapshot названия и суммы отдельно.
struct FineTemplate: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор шаблона штрафа.
    let id: UUID
    /// Точка, для которой действует данный шаблон.
    let pointID: UUID
    /// Название штрафа для выбора в каталоге.
    let title: String
    /// Сумма штрафа по шаблону.
    let amount: Money
    /// Признак того, что штраф доступен в каталоге.
    let isActive: Bool
    /// Порядок сортировки в интерфейсе.
    let sortOrder: Int

    init(
        id: UUID = UUID(),
        pointID: UUID,
        title: String,
        amount: Money,
        isActive: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.pointID = pointID
        self.title = title
        self.amount = amount
        self.isActive = isActive
        self.sortOrder = sortOrder
    }
}
