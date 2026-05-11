import FirebaseFirestore
import Foundation

nonisolated struct FirebaseUserDTO: Codable, Hashable, Sendable {
    let id: String
    let firstName: String
    let lastName: String
    let role: String
    let accountStatus: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName
        case lastName
        case role
        case accountStatus
        case createdAt
        case updatedAt
    }

    init(
        id: String,
        firstName: String,
        lastName: String,
        role: String,
        accountStatus: String,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.role = role
        self.accountStatus = accountStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(documentID: String, data: [String: Any]) throws {
        self.id = try FirebaseDTOValueDecoder.string(data["id"] ?? documentID, field: CodingKeys.id.stringValue)
        self.firstName = try FirebaseDTOValueDecoder.string(data["firstName"], field: CodingKeys.firstName.stringValue)
        self.lastName = try FirebaseDTOValueDecoder.string(data["lastName"], field: CodingKeys.lastName.stringValue)
        self.role = try FirebaseDTOValueDecoder.string(data["role"], field: CodingKeys.role.stringValue)
        self.accountStatus = try FirebaseDTOValueDecoder.string(data["accountStatus"], field: CodingKeys.accountStatus.stringValue)
        self.createdAt = try FirebaseDTOValueDecoder.optionalDate(data["createdAt"], field: CodingKeys.createdAt.stringValue)
        self.updatedAt = try FirebaseDTOValueDecoder.optionalDate(data["updatedAt"], field: CodingKeys.updatedAt.stringValue)
    }
}
