import Foundation

nonisolated struct FirebaseFineSummaryDTO: Codable, Hashable, Sendable {
    struct Row: Codable, Hashable, Sendable {
        let fineNameSnapshot: String
        let count: Int
        let priceSnapshot: Int
    }

    let totalCount: Int
    let totalAmountKopecks: Int
    let rows: [Row]
}
