import Foundation

/// Факт проката внутри смены.
///
/// Заказ хранит и ссылки на каталог (`rentalTypeID`, `rentedAssetIDs`), и snapshot
/// названий/номеров. Такой двойной формат позволяет работать с актуальными объектами
/// во время смены и при этом не ломать историю после изменений каталога.
struct RentalOrder: Identifiable, Hashable, Codable, Sendable {
    private enum Constants {
        static let defaultPeriodMinutes = 20
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case rentalTypeID
        case rentalTypeNameSnapshot
        case rentedAssetIDs
        case rentedAssetNumbersSnapshot
        case rentedItemsSnapshot
        case createdAt
        case startedAt
        case expectedEndAt
        case finishedAt
        case canceledAt
        case durationMinutes
        case totalPrice
        case paymentMethod
        case status
        case notes
        case rentalPeriodsCount
    }

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
    /// Количество оплаченных периодов проката. Продление добавляет еще один период
    /// тех же объектов и должно считаться как дополнительные сдачи в отчетах.
    let rentalPeriodsCount: Int
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
        rentalPeriodsCount: Int = 1,
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
        self.rentalPeriodsCount = max(1, rentalPeriodsCount)
        self.paymentMethod = paymentMethod
        self.status = status
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        rentalTypeID = try container.decode(UUID.self, forKey: .rentalTypeID)
        rentalTypeNameSnapshot = try container.decode(String.self, forKey: .rentalTypeNameSnapshot)
        rentedAssetIDs = try container.decodeIfPresent([UUID].self, forKey: .rentedAssetIDs) ?? []
        rentedAssetNumbersSnapshot = try container.decodeIfPresent([String].self, forKey: .rentedAssetNumbersSnapshot) ?? []
        rentedItemsSnapshot = try container.decodeIfPresent([RentalOrderItemSnapshot].self, forKey: .rentedItemsSnapshot) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        expectedEndAt = try container.decode(Date.self, forKey: .expectedEndAt)
        finishedAt = try container.decodeIfPresent(Date.self, forKey: .finishedAt)
        canceledAt = try container.decodeIfPresent(Date.self, forKey: .canceledAt)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        totalPrice = try container.decode(Money.self, forKey: .totalPrice)
        let inferredPeriodsCount = max(1, durationMinutes / Constants.defaultPeriodMinutes)
        rentalPeriodsCount = max(
            1,
            try container.decodeIfPresent(Int.self, forKey: .rentalPeriodsCount) ?? inferredPeriodsCount
        )
        paymentMethod = try container.decodeIfPresent(PaymentMethod.self, forKey: .paymentMethod) ?? .card
        status = try container.decode(RentalOrderStatus.self, forKey: .status)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(rentalTypeID, forKey: .rentalTypeID)
        try container.encode(rentalTypeNameSnapshot, forKey: .rentalTypeNameSnapshot)
        try container.encode(rentedAssetIDs, forKey: .rentedAssetIDs)
        try container.encode(rentedAssetNumbersSnapshot, forKey: .rentedAssetNumbersSnapshot)
        try container.encode(rentedItemsSnapshot, forKey: .rentedItemsSnapshot)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(expectedEndAt, forKey: .expectedEndAt)
        try container.encodeIfPresent(finishedAt, forKey: .finishedAt)
        try container.encodeIfPresent(canceledAt, forKey: .canceledAt)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(totalPrice, forKey: .totalPrice)
        try container.encode(rentalPeriodsCount, forKey: .rentalPeriodsCount)
        try container.encode(paymentMethod, forKey: .paymentMethod)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(notes, forKey: .notes)
    }

    var quantity: Int {
        // Новые смешанные заказы считают количество по item snapshot. Старый массив
        // номеров оставлен для совместимости с ранними MVP-записями.
        if !rentedItemsSnapshot.isEmpty {
            return rentedItemsSnapshot.count
        }

        return rentedAssetNumbersSnapshot.count
    }

    var billableTripsCount: Int {
        quantity * rentalPeriodsCount
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
            rentalPeriodsCount: rentalPeriodsCount,
            paymentMethod: paymentMethod ?? self.paymentMethod,
            status: .completed,
            notes: notes
        )
    }

    func extended(byMinutes minutes: Int, additionalPrice: Money) -> RentalOrder {
        RentalOrder(
            id: id,
            rentalTypeID: rentalTypeID,
            rentalTypeNameSnapshot: rentalTypeNameSnapshot,
            rentedAssetIDs: rentedAssetIDs,
            rentedAssetNumbersSnapshot: rentedAssetNumbersSnapshot,
            rentedItemsSnapshot: rentedItemsSnapshot,
            createdAt: createdAt,
            startedAt: startedAt,
            expectedEndAt: expectedEndAt.addingTimeInterval(TimeInterval(minutes * 60)),
            finishedAt: finishedAt,
            canceledAt: canceledAt,
            durationMinutes: durationMinutes + minutes,
            totalPrice: totalPrice + additionalPrice,
            rentalPeriodsCount: rentalPeriodsCount + 1,
            paymentMethod: paymentMethod,
            status: status,
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
            rentalPeriodsCount: rentalPeriodsCount,
            paymentMethod: paymentMethod,
            status: .canceled,
            notes: notes
        )
    }
}
