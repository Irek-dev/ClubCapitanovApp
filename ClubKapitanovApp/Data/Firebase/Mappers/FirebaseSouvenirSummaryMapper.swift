import Foundation

nonisolated enum FirebaseSouvenirSummaryMapper {
    static func makeDTO(from summary: ShiftSouvenirCloseSummary) -> FirebaseSouvenirSummaryDTO {
        FirebaseSouvenirSummaryDTO(
            totalRevenueKopecks: summary.totalRevenue.kopecks,
            rows: summary.rows.map {
                FirebaseSouvenirSummaryDTO.Row(
                    souvenirNameSnapshot: $0.title,
                    count: $0.count,
                    priceSnapshot: $0.amount.kopecks
                )
            }
        )
    }
}
