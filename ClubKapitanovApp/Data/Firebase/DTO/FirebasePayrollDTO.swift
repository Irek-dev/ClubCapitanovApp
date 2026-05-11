import Foundation

nonisolated struct FirebasePayrollDTO: Codable, Hashable, Sendable {
    struct Row: Codable, Hashable, Sendable {
        let participantID: String
        let employeeID: String
        let userNameSnapshot: String
        let roleSnapshot: String
        let joinedAt: Date
        let leftAt: Date?
        let paidUntilAt: Date
        let workedDurationSeconds: TimeInterval
        let participatedTripsCount: Int
        let amountKopecks: Int
    }

    let ratePerTripKopecks: Int
    let totalTripsCount: Int
    let totalFundKopecks: Int
    let totalAmountKopecks: Int
    let payrollSnapshot: [Row]
}
