import Foundation

nonisolated enum FirebaseFineSummaryMapper {
    static func makeDTO(from summary: ShiftFinesCloseSummary) -> FirebaseFineSummaryDTO {
        FirebaseFineSummaryDTO(
            totalCount: summary.totalCount,
            totalAmountKopecks: summary.totalAmount.kopecks,
            rows: summary.rows.map {
                FirebaseFineSummaryDTO.Row(
                    fineNameSnapshot: $0.title,
                    count: $0.count,
                    priceSnapshot: $0.amount.kopecks
                )
            }
        )
    }
}
