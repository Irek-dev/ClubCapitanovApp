import Foundation

/// Конкретная единица проката с номером или видимым обозначением.
///
/// Эта сущность нужна не только для списка доступного оборудования, но и для истории:
/// `RentalOrder` сохраняет snapshot выданных номеров, чтобы старый заказ оставался
/// понятным даже после изменения каталога или списания объекта.
struct RentalAsset: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор конкретной единицы проката.
    let id: UUID
    /// Точка, к которой относится конкретная единица.
    let pointID: UUID
    /// Тип проката, к которому относится конкретная единица.
    let rentalTypeID: UUID
    /// Номер или имя, по которому сотрудник распознает единицу.
    let displayNumber: String
    /// Признак того, что единица проката доступна в работе.
    let isActive: Bool

    init(
        id: UUID = UUID(),
        pointID: UUID,
        rentalTypeID: UUID,
        displayNumber: String,
        isActive: Bool = true
    ) {
        self.id = id
        self.pointID = pointID
        self.rentalTypeID = rentalTypeID
        self.displayNumber = displayNumber
        self.isActive = isActive
    }
}
