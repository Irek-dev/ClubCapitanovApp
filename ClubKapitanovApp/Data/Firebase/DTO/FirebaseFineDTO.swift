import Foundation

nonisolated struct FirebaseFineDTO: Codable, Hashable, Sendable {
    let id: String
    let templateID: String?
    let fineNameSnapshot: String
    let priceSnapshot: Int
    let createdAt: Date
    let createdByEmployeeID: String
    let userNameSnapshot: String
    let paymentMethod: String
    let notes: String?
}
