import Foundation

nonisolated struct FirebaseEquipmentDTO: Codable, Hashable, Sendable {
    let id: String
    let pointID: String
    let rentalTypeID: String?
    let name: String
    let code: String?
    let totalCount: Int
    let workingCount: Int
    let discardedCount: Int
    let isActive: Bool
    let updatedAt: Date?
}
