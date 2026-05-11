import Foundation

nonisolated struct FirebaseShiftReportDTO: Codable, Hashable, Sendable {
    struct PaymentRevenue: Codable, Hashable, Sendable {
        let paymentMethod: String
        let amountKopecks: Int
    }

    let id: String
    let reportNumber: String
    let shiftID: String
    let pointID: String
    let pointNameSnapshot: String
    let shiftDate: Date
    let createdAt: Date
    let createdByUserID: String
    let userNameSnapshot: String
    let weatherNote: String?
    let totalRevenueKopecks: Int
    let rentalRevenueKopecks: Int
    let souvenirRevenueKopecks: Int
    let finesRevenueKopecks: Int
    let payrollTotalKopecks: Int?
    let paymentRevenue: [PaymentRevenue]
    let rentalTripsCount: Int
    let souvenirItemsCount: Int
    let finesCount: Int
    let equipmentNotes: String?
    let batteryNotes: String?
    let notes: String?
    let textReport: String?
    let inventoryAppliedAt: Date?
}
