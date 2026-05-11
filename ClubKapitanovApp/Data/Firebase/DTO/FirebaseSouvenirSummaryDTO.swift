import Foundation

nonisolated struct FirebaseSouvenirSummaryDTO: Codable, Hashable, Sendable {
    struct Row: Codable, Hashable, Sendable {
        let souvenirNameSnapshot: String
        let count: Int
        let priceSnapshot: Int
    }

    let totalRevenueKopecks: Int
    let rows: [Row]
}
