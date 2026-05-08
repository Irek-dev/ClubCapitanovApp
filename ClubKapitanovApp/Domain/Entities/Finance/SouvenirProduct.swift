import Foundation

/// Товар сувенирки из каталога конкретной точки.
///
/// Это "живой" каталог: цену, активность и порядок показа можно менять для будущих
/// продаж. Уже проведенные продажи должны хранить snapshot названия и цены в
/// `SouvenirSale`, чтобы история не пересчитывалась при изменении каталога.
struct SouvenirProduct: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор товара сувенирки.
    let id: UUID
    /// Точка, к которой относится товар.
    let pointID: UUID
    /// Название товара.
    let name: String
    /// Цена товара.
    let price: Money
    /// Признак того, что товар активен и доступен для продажи.
    let isActive: Bool
    /// Порядок показа товара в каталоге.
    let sortOrder: Int

    init(
        id: UUID = UUID(),
        pointID: UUID,
        name: String,
        price: Money,
        isActive: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.pointID = pointID
        self.name = name
        self.price = price
        self.isActive = isActive
        self.sortOrder = sortOrder
    }
}
