import Foundation

/// Тип батареек на конкретной точке и текущий учетный остаток.
struct BatteryItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let pointID: UUID
    let title: String
    let quantity: Int

    init(
        id: UUID = UUID(),
        pointID: UUID,
        title: String,
        quantity: Int = 0
    ) {
        self.id = id
        self.pointID = pointID
        self.title = title
        self.quantity = max(0, quantity)
    }
}
