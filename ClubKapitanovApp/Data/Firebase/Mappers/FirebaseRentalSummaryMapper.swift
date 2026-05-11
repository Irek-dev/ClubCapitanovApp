import Foundation

nonisolated enum FirebaseRentalSummaryMapper {
    static func makeDTO(from summary: ShiftRentalCloseSummary) -> FirebaseRentalSummaryDTO {
        FirebaseRentalSummaryDTO(
            totalTripsCount: summary.totalTripsCount,
            revenueKopecks: summary.revenue.kopecks,
            tripsByType: summary.tripsByType.map {
                FirebaseRentalSummaryDTO.RentalTypeRow(
                    rentalTypeNameSnapshot: $0.title,
                    count: $0.count
                )
            },
            tariffBreakdown: summary.tariffBreakdown.map {
                FirebaseRentalSummaryDTO.TariffRow(
                    tariffTitleSnapshot: $0.title,
                    amountKopecks: $0.amount.kopecks
                )
            },
            payments: summary.payments.map {
                FirebaseRentalSummaryDTO.PaymentRow(
                    paymentMethod: $0.paymentMethod.rawValue,
                    amountKopecks: $0.amount.kopecks
                )
            },
            chipRevenueKopecks: summary.chipRevenue?.kopecks
        )
    }
}
