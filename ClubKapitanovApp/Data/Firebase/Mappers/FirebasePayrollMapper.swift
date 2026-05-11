import Foundation

nonisolated enum FirebasePayrollMapper {
    static func makeDTO(from summary: ShiftPayrollCloseSummary) -> FirebasePayrollDTO {
        FirebasePayrollDTO(
            ratePerTripKopecks: summary.ratePerTrip.kopecks,
            totalTripsCount: summary.totalTripsCount,
            totalFundKopecks: summary.totalFund.kopecks,
            totalAmountKopecks: summary.totalAmount.kopecks,
            payrollSnapshot: summary.rows.map {
                FirebasePayrollDTO.Row(
                    participantID: $0.participantID.uuidString,
                    employeeID: $0.employeeID.uuidString,
                    userNameSnapshot: $0.employeeName,
                    roleSnapshot: $0.roleSnapshot.rawValue,
                    joinedAt: $0.joinedAt,
                    leftAt: $0.leftAt,
                    paidUntilAt: $0.paidUntilAt,
                    workedDurationSeconds: $0.workedDurationSeconds,
                    participatedTripsCount: $0.participatedTripsCount,
                    amountKopecks: $0.amount.kopecks
                )
            }
        )
    }
}
