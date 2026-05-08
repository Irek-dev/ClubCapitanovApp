import Foundation

/// Факт проката внутри смены.
///
/// Заказ хранит и ссылки на каталог (`rentalTypeID`, `rentedAssetIDs`), и snapshot
/// названий/номеров. Такой двойной формат позволяет работать с актуальными объектами
/// во время смены и при этом не ломать историю после изменений каталога.
struct RentalOrder: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор заказа аренды.
    let id: UUID
    /// Идентификатор типа проката.
    let rentalTypeID: UUID
    /// Название типа проката в том виде, в котором оно должно остаться в истории.
    let rentalTypeNameSnapshot: String
    /// Идентификаторы конкретных единиц проката, выданных клиенту.
    let rentedAssetIDs: [UUID]
    /// Номера конкретных единиц проката для истории и активного заказа.
    let rentedAssetNumbersSnapshot: [String]
    /// Конкретные объекты заказа. Используется для смешанных заказов, где в одном
    /// заказе могут быть утка, яхта и катер одновременно.
    let rentedItemsSnapshot: [RentalOrderItemSnapshot]
    /// Время создания заказа в системе.
    let createdAt: Date
    /// Фактическое время начала аренды.
    let startedAt: Date
    /// Плановое время завершения заказа, по которому локально считается таймер.
    let expectedEndAt: Date
    /// Время завершения аренды, если заказ уже закрыт.
    let finishedAt: Date?
    /// Время отмены заказа, если он был отменен.
    let canceledAt: Date?
    /// Длительность аренды в минутах.
    let durationMinutes: Int
    /// Итоговая стоимость заказа аренды.
    let totalPrice: Money
    /// Способ оплаты аренды.
    let paymentMethod: PaymentMethod
    /// Текущее состояние заказа аренды.
    let status: RentalOrderStatus
    /// Дополнительная заметка к заказу.
    let notes: String?

    init(
        id: UUID = UUID(),
        rentalTypeID: UUID,
        rentalTypeNameSnapshot: String,
        rentedAssetIDs: [UUID] = [],
        rentedAssetNumbersSnapshot: [String] = [],
        rentedItemsSnapshot: [RentalOrderItemSnapshot] = [],
        createdAt: Date,
        startedAt: Date,
        expectedEndAt: Date,
        finishedAt: Date? = nil,
        canceledAt: Date? = nil,
        durationMinutes: Int,
        totalPrice: Money,
        paymentMethod: PaymentMethod = .card,
        status: RentalOrderStatus,
        notes: String? = nil
    ) {
        self.id = id
        self.rentalTypeID = rentalTypeID
        self.rentalTypeNameSnapshot = rentalTypeNameSnapshot
        self.rentedAssetIDs = rentedAssetIDs
        self.rentedAssetNumbersSnapshot = rentedAssetNumbersSnapshot
        self.rentedItemsSnapshot = rentedItemsSnapshot
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.expectedEndAt = expectedEndAt
        self.finishedAt = finishedAt
        self.canceledAt = canceledAt
        self.durationMinutes = durationMinutes
        self.totalPrice = totalPrice
        self.paymentMethod = paymentMethod
        self.status = status
        self.notes = notes
    }

    var quantity: Int {
        // Новые смешанные заказы считают количество по item snapshot. Старый массив
        // номеров оставлен для совместимости с ранними MVP-записями.
        if !rentedItemsSnapshot.isEmpty {
            return rentedItemsSnapshot.count
        }

        return rentedAssetNumbersSnapshot.count
    }

    func completed(at finishedAt: Date, paymentMethod: PaymentMethod? = nil) -> RentalOrder {
        RentalOrder(
            id: id,
            rentalTypeID: rentalTypeID,
            rentalTypeNameSnapshot: rentalTypeNameSnapshot,
            rentedAssetIDs: rentedAssetIDs,
            rentedAssetNumbersSnapshot: rentedAssetNumbersSnapshot,
            rentedItemsSnapshot: rentedItemsSnapshot,
            createdAt: createdAt,
            startedAt: startedAt,
            expectedEndAt: expectedEndAt,
            finishedAt: finishedAt,
            canceledAt: nil,
            durationMinutes: durationMinutes,
            totalPrice: totalPrice,
            paymentMethod: paymentMethod ?? self.paymentMethod,
            status: .completed,
            notes: notes
        )
    }

    func canceled(at canceledAt: Date) -> RentalOrder {
        RentalOrder(
            id: id,
            rentalTypeID: rentalTypeID,
            rentalTypeNameSnapshot: rentalTypeNameSnapshot,
            rentedAssetIDs: rentedAssetIDs,
            rentedAssetNumbersSnapshot: rentedAssetNumbersSnapshot,
            rentedItemsSnapshot: rentedItemsSnapshot,
            createdAt: createdAt,
            startedAt: startedAt,
            expectedEndAt: expectedEndAt,
            finishedAt: nil,
            canceledAt: canceledAt,
            durationMinutes: durationMinutes,
            totalPrice: totalPrice,
            paymentMethod: paymentMethod,
            status: .canceled,
            notes: notes
        )
    }
}
