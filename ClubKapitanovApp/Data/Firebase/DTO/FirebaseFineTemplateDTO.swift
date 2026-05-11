import Foundation

nonisolated struct FirebaseFineTemplateDTO: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let amountKopecks: Int
    let sortOrder: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case amountKopecks
        case sortOrder
        case createdAt
        case updatedAt
    }

    init(
        id: String,
        name: String,
        amountKopecks: Int,
        sortOrder: Int,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.amountKopecks = amountKopecks
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(documentID: String, data: [String: Any]) throws {
        self.id = try FirebaseDTOValueDecoder.string(data["id"] ?? documentID, field: CodingKeys.id.stringValue)
        self.name = try FirebaseDTOValueDecoder.string(data["name"], field: CodingKeys.name.stringValue)
        self.amountKopecks = try FirebaseDTOValueDecoder.int(data["amountKopecks"], field: CodingKeys.amountKopecks.stringValue)
        self.sortOrder = try FirebaseDTOValueDecoder.int(data["sortOrder"], field: CodingKeys.sortOrder.stringValue)
        self.createdAt = try FirebaseDTOValueDecoder.optionalDate(data["createdAt"], field: CodingKeys.createdAt.stringValue)
        self.updatedAt = try FirebaseDTOValueDecoder.optionalDate(data["updatedAt"], field: CodingKeys.updatedAt.stringValue)
    }
}
