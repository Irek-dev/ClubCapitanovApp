import Foundation

nonisolated struct FirebaseRentalOrderDTO: Codable, Hashable, Sendable {
    struct ItemSnapshot: Codable, Hashable, Sendable {
        let rentalTypeID: String
        let rentalTypeNameSnapshot: String
        let rentalTypeCodeSnapshot: String
        let displayNumber: Int
        let rentalTariffID: String?
        let tariffTitleSnapshot: String?
        let tariffDurationMinutes: Int?
        let priceSnapshot: Int?
        let payrollSnapshot: Int?
    }

    let id: String
    let rentalTypeID: String
    let rentalTypeNameSnapshot: String
    let rentedAssetIDs: [String]
    let rentedAssetNumbersSnapshot: [String]
    let rentedItemsSnapshot: [ItemSnapshot]
    let createdAt: Date
    let startedAt: Date
    let expectedEndAt: Date
    let finishedAt: Date?
    let canceledAt: Date?
    let durationMinutes: Int
    let quantity: Int
    let rentalPeriodsCount: Int
    let billableTripsCount: Int
    let priceSnapshot: Int
    let payrollSnapshot: Int?
    let paymentMethod: String
    let status: String
    let notes: String?
}
