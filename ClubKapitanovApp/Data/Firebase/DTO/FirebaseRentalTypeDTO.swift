import Foundation

nonisolated struct FirebaseRentalTypeDTO: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let shortCode: String
    let priceKopecks: Int
    let durationMinutes: Int
    let payrollKopecks: Int
    let stockQuantity: Int
    let sortOrder: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case shortCode
        case priceKopecks
        case durationMinutes
        case payrollKopecks
        case stockQuantity
        case sortOrder
        case createdAt
        case updatedAt
    }

    init(
        id: String,
        name: String,
        shortCode: String,
        priceKopecks: Int,
        durationMinutes: Int,
        payrollKopecks: Int,
        stockQuantity: Int,
        sortOrder: Int,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.shortCode = shortCode
        self.priceKopecks = priceKopecks
        self.durationMinutes = durationMinutes
        self.payrollKopecks = payrollKopecks
        self.stockQuantity = stockQuantity
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(documentID: String, data: [String: Any]) throws {
        self.id = try FirebaseDTOValueDecoder.string(data["id"] ?? documentID, field: CodingKeys.id.stringValue)
        self.name = try FirebaseDTOValueDecoder.string(data["name"], field: CodingKeys.name.stringValue)
        self.shortCode = try FirebaseDTOValueDecoder.string(data["shortCode"], field: CodingKeys.shortCode.stringValue)
        self.priceKopecks = try FirebaseDTOValueDecoder.int(data["priceKopecks"], field: CodingKeys.priceKopecks.stringValue)
        self.durationMinutes = try FirebaseDTOValueDecoder.int(data["durationMinutes"], field: CodingKeys.durationMinutes.stringValue)
        self.payrollKopecks = try FirebaseDTOValueDecoder.int(data["payrollKopecks"], field: CodingKeys.payrollKopecks.stringValue)
        self.stockQuantity = try FirebaseDTOValueDecoder.int(data["stockQuantity"], field: CodingKeys.stockQuantity.stringValue)
        self.sortOrder = try FirebaseDTOValueDecoder.int(data["sortOrder"], field: CodingKeys.sortOrder.stringValue)
        self.createdAt = try FirebaseDTOValueDecoder.optionalDate(data["createdAt"], field: CodingKeys.createdAt.stringValue)
        self.updatedAt = try FirebaseDTOValueDecoder.optionalDate(data["updatedAt"], field: CodingKeys.updatedAt.stringValue)
    }
}
