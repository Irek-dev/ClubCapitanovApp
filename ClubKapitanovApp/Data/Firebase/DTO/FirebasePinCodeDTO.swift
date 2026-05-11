import FirebaseFirestore
import Foundation

nonisolated struct FirebasePinCodeDTO: Codable, Hashable, Sendable {
    let pinCode: String
    let userID: String
    let firstNameSnapshot: String
    let lastNameSnapshot: String
    let roleSnapshot: String
    let accountStatusSnapshot: String
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case pinCode
        case userID
        case firstNameSnapshot
        case lastNameSnapshot
        case roleSnapshot
        case accountStatusSnapshot
        case updatedAt
    }

    init(
        pinCode: String,
        userID: String,
        firstNameSnapshot: String,
        lastNameSnapshot: String,
        roleSnapshot: String,
        accountStatusSnapshot: String,
        updatedAt: Date?
    ) {
        self.pinCode = pinCode
        self.userID = userID
        self.firstNameSnapshot = firstNameSnapshot
        self.lastNameSnapshot = lastNameSnapshot
        self.roleSnapshot = roleSnapshot
        self.accountStatusSnapshot = accountStatusSnapshot
        self.updatedAt = updatedAt
    }

    init(documentID: String, data: [String: Any]) throws {
        self.pinCode = try FirebaseDTOValueDecoder.string(data["pinCode"] ?? documentID, field: CodingKeys.pinCode.stringValue)
        self.userID = try FirebaseDTOValueDecoder.string(data["userID"] ?? data["userId"], field: CodingKeys.userID.stringValue)
        self.firstNameSnapshot = try FirebaseDTOValueDecoder.string(data["firstNameSnapshot"], field: CodingKeys.firstNameSnapshot.stringValue)
        self.lastNameSnapshot = try FirebaseDTOValueDecoder.string(data["lastNameSnapshot"], field: CodingKeys.lastNameSnapshot.stringValue)
        self.roleSnapshot = try FirebaseDTOValueDecoder.string(data["roleSnapshot"], field: CodingKeys.roleSnapshot.stringValue)
        self.accountStatusSnapshot = try FirebaseDTOValueDecoder.string(data["accountStatusSnapshot"], field: CodingKeys.accountStatusSnapshot.stringValue)
        self.updatedAt = try FirebaseDTOValueDecoder.optionalDate(data["updatedAt"], field: CodingKeys.updatedAt.stringValue)
    }
}
