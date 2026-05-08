import Foundation

/// Snapshot конкретного объекта внутри заказа проката.
///
/// Один заказ может содержать разные типы объектов, поэтому данные каждой единицы
/// хранятся отдельно от общего `RentalOrder`.
struct RentalOrderItemSnapshot: Hashable, Codable, Sendable {
    let rentalTypeID: UUID
    let rentalTypeNameSnapshot: String
    let rentalTypeCodeSnapshot: String
    let displayNumber: Int
    /// Snapshot тарифа нужен, чтобы история не пересчитывалась после изменения цен.
    let rentalTariffID: UUID?
    let tariffTitleSnapshot: String?
    let tariffDurationMinutes: Int?
    let tariffPriceSnapshot: Money?

    init(
        rentalTypeID: UUID,
        rentalTypeNameSnapshot: String,
        rentalTypeCodeSnapshot: String,
        displayNumber: Int,
        rentalTariffID: UUID? = nil,
        tariffTitleSnapshot: String? = nil,
        tariffDurationMinutes: Int? = nil,
        tariffPriceSnapshot: Money? = nil
    ) {
        self.rentalTypeID = rentalTypeID
        self.rentalTypeNameSnapshot = rentalTypeNameSnapshot
        self.rentalTypeCodeSnapshot = rentalTypeCodeSnapshot
        self.displayNumber = displayNumber
        self.rentalTariffID = rentalTariffID
        self.tariffTitleSnapshot = tariffTitleSnapshot
        self.tariffDurationMinutes = tariffDurationMinutes
        self.tariffPriceSnapshot = tariffPriceSnapshot
    }
}
