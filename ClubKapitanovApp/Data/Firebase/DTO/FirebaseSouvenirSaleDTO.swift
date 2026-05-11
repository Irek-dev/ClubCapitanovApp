import Foundation

nonisolated struct FirebaseSouvenirSaleDTO: Codable, Hashable, Sendable {
    let id: String
    let productID: String?
    let souvenirNameSnapshot: String
    let quantity: Int
    let priceSnapshot: Int
    let totalPriceKopecks: Int
    let soldAt: Date
    let soldByEmployeeID: String
    let userNameSnapshot: String
    let paymentMethod: String
    let notes: String?
}
