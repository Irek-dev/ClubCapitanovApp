import Foundation

nonisolated struct FirebaseBatterySnapshotDTO: Codable, Hashable, Sendable {
    struct Row: Codable, Hashable, Sendable {
        let batteryNameSnapshot: String
        let count: Int
    }

    let workingTotal: Int?
    let workingRows: [Row]
    let discardedRows: [Row]
    let notes: String?
}
