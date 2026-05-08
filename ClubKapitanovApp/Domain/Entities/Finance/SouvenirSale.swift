import Foundation

/// Факт продажи сувенирной продукции внутри смены.
///
/// В отличие от `SouvenirProduct`, эта сущность историческая: она хранит название,
/// цену и количество на момент продажи. Поэтому отчет закрытой смены не зависит от
/// будущих изменений каталога или цены товара.
struct SouvenirSale: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор продажи.
    let id: UUID
    /// Идентификатор товара из каталога точки, если продажа проведена по каталогу.
    let productID: UUID?
    /// Название проданного товара.
    let itemName: String
    /// Количество проданных единиц товара.
    let quantity: Int
    /// Цена одной единицы товара.
    let unitPrice: Money
    /// Общая сумма продажи.
    let totalPrice: Money
    /// Дата и время проведения продажи.
    let soldAt: Date
    /// Сотрудник, оформивший продажу.
    let soldByEmployeeID: UUID
    /// Способ оплаты продажи.
    let paymentMethod: PaymentMethod
    /// Дополнительная заметка по продаже.
    let notes: String?

    init(
        id: UUID = UUID(),
        productID: UUID? = nil,
        itemName: String,
        quantity: Int,
        unitPrice: Money,
        totalPrice: Money,
        soldAt: Date,
        soldByEmployeeID: UUID,
        paymentMethod: PaymentMethod = .card,
        notes: String? = nil
    ) {
        // `productID` может быть nil для будущих ручных продаж, но snapshot-поля
        // `itemName`, `unitPrice`, `totalPrice` обязательны для корректной истории.
        self.id = id
        self.productID = productID
        self.itemName = itemName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.soldAt = soldAt
        self.soldByEmployeeID = soldByEmployeeID
        self.paymentMethod = paymentMethod
        self.notes = notes
    }
}
