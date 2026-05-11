import Foundation

nonisolated struct FirebasePointDTO: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let city: String
    let address: String
    let status: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case city
        case address
        case status
        case createdAt
        case updatedAt
    }

    init(
        id: String,
        name: String,
        city: String,
        address: String,
        status: String,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.address = address
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(documentID: String, data: [String: Any]) throws {
        self.id = try FirebaseDTOValueDecoder.string(data["id"] ?? documentID, field: CodingKeys.id.stringValue)
        self.name = try FirebaseDTOValueDecoder.string(data["name"], field: CodingKeys.name.stringValue)
        self.city = data["city"] as? String ?? ""
        self.address = data["address"] as? String ?? ""
        self.status = try FirebaseDTOValueDecoder.string(data["status"], field: CodingKeys.status.stringValue)
        self.createdAt = try FirebaseDTOValueDecoder.optionalDate(data["createdAt"], field: CodingKeys.createdAt.stringValue)
        self.updatedAt = try FirebaseDTOValueDecoder.optionalDate(data["updatedAt"], field: CodingKeys.updatedAt.stringValue)
    }
}
