import Foundation

nonisolated struct FirebaseEquipmentSnapshotDTO: Codable, Hashable, Sendable {
    struct Row: Codable, Hashable, Sendable {
        let equipmentNameSnapshot: String
        let count: Int
    }

    let workingRows: [Row]
    let discardedRows: [Row]
    let notes: String?
}
