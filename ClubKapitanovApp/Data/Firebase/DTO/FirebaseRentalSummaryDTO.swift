import Foundation

nonisolated struct FirebaseRentalSummaryDTO: Codable, Hashable, Sendable {
    struct RentalTypeRow: Codable, Hashable, Sendable {
        let rentalTypeNameSnapshot: String
        let count: Int
    }

    struct TariffRow: Codable, Hashable, Sendable {
        let tariffTitleSnapshot: String
        let amountKopecks: Int
    }

    struct PaymentRow: Codable, Hashable, Sendable {
        let paymentMethod: String
        let amountKopecks: Int
    }

    let totalTripsCount: Int
    let revenueKopecks: Int
    let tripsByType: [RentalTypeRow]
    let tariffBreakdown: [TariffRow]
    let payments: [PaymentRow]
    let chipRevenueKopecks: Int?
}
