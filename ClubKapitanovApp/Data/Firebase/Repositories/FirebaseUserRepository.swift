import FirebaseFirestore
import Foundation

final class FirebaseUserRepository: AdminUserRepository {
    private enum Collection {
        static let users = "users"
        static let pinCodes = "pinCodes"
    }

    private enum Field {
        static let userID = "userID"
    }

    private enum Constants {
        static let pinRange = 1000...9999
    }

    private let db: Firestore
    private var users: [User] = []
    private var firestoreUserIDsByDomainID: [UUID: String] = [:]
    private(set) var lastLoadError: Error?

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func getUser(
        pinCode: String,
        completion: @escaping (Result<User?, Error>) -> Void
    ) {
        let normalizedPIN = pinCode.trimmingCharacters(in: .whitespacesAndNewlines)

        pinCodeReference(normalizedPIN).getDocument(source: .server) { [weak self] pinSnapshot, error in
            guard let self else { return }

            if let error {
                self.debugLog("pin load failed", error: error, path: self.pinCodeReference(normalizedPIN).path)
                self.completeOnMain(.failure(error), completion: completion)
                return
            }

            guard
                let pinSnapshot,
                pinSnapshot.exists,
                let pinData = pinSnapshot.data()
            else {
                self.completeOnMain(.success(nil), completion: completion)
                return
            }

            let pinDTO: FirebasePinCodeDTO
            do {
                pinDTO = try FirebasePinCodeDTO(documentID: pinSnapshot.documentID, data: pinData)
            } catch {
                self.debugLog("pin decode failed", error: error, path: pinSnapshot.reference.path, data: pinData)
                self.completeOnMain(.failure(FirebaseUserRepositoryError.invalidPINDocument), completion: completion)
                return
            }

            guard let pinStatus = UserAccountStatus(rawValue: pinDTO.accountStatusSnapshot) else {
                self.debugLog(
                    "pin status decode failed",
                    path: pinSnapshot.reference.path,
                    data: ["accountStatusSnapshot": pinDTO.accountStatusSnapshot]
                )
                self.completeOnMain(.failure(FirebaseUserRepositoryError.invalidPINDocument), completion: completion)
                return
            }

            guard pinStatus == .active else {
                self.completeOnMain(.failure(FirebaseUserRepositoryError.inactiveUser), completion: completion)
                return
            }

            self.userReference(firestoreID: pinDTO.userID).getDocument(source: .server) { [weak self] userSnapshot, error in
                guard let self else { return }

                if let error {
                    self.debugLog("user load failed", error: error, path: self.userReference(firestoreID: pinDTO.userID).path)
                    self.completeOnMain(.failure(error), completion: completion)
                    return
                }

                guard
                    let userSnapshot,
                    userSnapshot.exists,
                    let userData = userSnapshot.data()
                else {
                    self.debugLog("user document missing", path: self.userReference(firestoreID: pinDTO.userID).path)
                    self.completeOnMain(.success(nil), completion: completion)
                    return
                }

                let userDTO: FirebaseUserDTO
                do {
                    userDTO = try FirebaseUserDTO(documentID: userSnapshot.documentID, data: userData)
                } catch {
                    self.debugLog("user decode failed", error: error, path: userSnapshot.reference.path, data: userData)
                    self.completeOnMain(.failure(FirebaseUserRepositoryError.invalidUserDocument), completion: completion)
                    return
                }

                guard let user = self.makeUser(from: userDTO, pinCode: pinDTO.pinCode) else {
                    self.debugLog("user domain mapping failed", path: userSnapshot.reference.path, data: userData)
                    self.completeOnMain(.failure(FirebaseUserRepositoryError.invalidUserDocument), completion: completion)
                    return
                }

                guard user.canSignIn else {
                    self.completeOnMain(.failure(FirebaseUserRepositoryError.inactiveUser), completion: completion)
                    return
                }

                self.completeOnMain(.success(user), completion: completion)
            }
        }
    }

    func refreshUsers(completion: @escaping () -> Void) {
        loadUsers { [weak self] result in
            switch result {
            case let .success(users):
                self?.users = users
                self?.lastLoadError = nil
            case let .failure(error):
                self?.debugLog("users refresh failed", error: error)
                self?.lastLoadError = error
            }

            DispatchQueue.main.async {
                completion()
            }
        }
    }

    func getAllUsers(includeArchived: Bool = false) -> [User] {
        users
            .filter { includeArchived || $0.accountStatus != .archived }
            .sorted { lhs, rhs in
                if lhs.accountStatus != rhs.accountStatus {
                    return lhs.accountStatus == .active
                }

                return lhs.fullName < rhs.fullName
            }
    }

    func createUser(
        firstName: String,
        lastName: String,
        role: UserRole,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        let now = Date()
        let userID = UUID()
        let firestoreUserID = userID.uuidString
        let candidatePINs = makePINCandidates()

        db.runTransaction({ [weak self] transaction, errorPointer -> Any? in
            guard let self else { return nil }

            do {
                for pinCode in candidatePINs {
                    let pinReference = self.pinCodeReference(pinCode)
                    let pinSnapshot = try transaction.getDocument(pinReference)
                    guard !pinSnapshot.exists else {
                        continue
                    }

                    let user = User(
                        id: userID,
                        pinCode: pinCode,
                        firstName: firstName,
                        lastName: lastName,
                        role: role
                    )

                    transaction.setData(
                        self.makeUserData(
                            user,
                            firestoreUserID: firestoreUserID,
                            createdAt: now,
                            updatedAt: now
                        ),
                        forDocument: self.userReference(firestoreID: firestoreUserID)
                    )
                    transaction.setData(
                        self.makePinCodeData(
                            for: user,
                            firestoreUserID: firestoreUserID,
                            updatedAt: now
                        ),
                        forDocument: pinReference
                    )
                    return user
                }

                throw FirebaseUserRepositoryError.noAvailablePIN
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { [weak self] value, error in
            guard let self else { return }

            if let error {
                self.debugLog("create user failed", error: error)
                self.completeOnMain(.failure(error), completion: completion)
                return
            }

            guard let user = value as? User else {
                self.completeOnMain(.failure(FirebaseUserRepositoryError.emptyTransactionResult), completion: completion)
                return
            }

            self.firestoreUserIDsByDomainID[user.id] = firestoreUserID
            self.users.append(user)
            self.lastLoadError = nil
            self.completeOnMain(.success(user), completion: completion)
        }
    }

    func updateUser(
        _ user: User,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        guard !user.pinCode.isEmpty else {
            completeOnMain(.failure(FirebaseUserRepositoryError.missingPINCode), completion: completion)
            return
        }

        let now = Date()
        let firestoreUserID = firestoreUserID(for: user.id)
        let batch = db.batch()

        batch.setData(
            makeUserData(user, firestoreUserID: firestoreUserID, updatedAt: now),
            forDocument: userReference(firestoreID: firestoreUserID),
            merge: true
        )
        batch.setData(
            makePinCodeData(for: user, firestoreUserID: firestoreUserID, updatedAt: now),
            forDocument: pinCodeReference(user.pinCode)
        )

        batch.commit { [weak self] error in
            if let error {
                self?.debugLog("update user failed", error: error, path: self?.userReference(firestoreID: firestoreUserID).path)
                self?.completeOnMain(.failure(error), completion: completion)
                return
            }

            self?.firestoreUserIDsByDomainID[user.id] = firestoreUserID
            self?.upsertCachedUser(user)
            self?.lastLoadError = nil
            self?.completeOnMain(.success(user), completion: completion)
        }
    }

    func deleteUser(
        id: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let firestoreUserID = firestoreUserID(for: id)

        pinCodesCollection
            .whereField(Field.userID, isEqualTo: firestoreUserID)
            .getDocuments(source: .server) { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.debugLog("load user pins for delete failed", error: error)
                    self.completeOnMain(.failure(error), completion: completion)
                    return
                }

                let batch = self.db.batch()
                batch.deleteDocument(self.userReference(firestoreID: firestoreUserID))
                snapshot?.documents.forEach { document in
                    batch.deleteDocument(document.reference)
                }

                batch.commit { [weak self] error in
                    if let error {
                        self?.debugLog("delete user failed", error: error, path: self?.userReference(firestoreID: firestoreUserID).path)
                        self?.completeOnMain(.failure(error), completion: completion)
                        return
                    }

                    self?.users.removeAll { $0.id == id }
                    self?.firestoreUserIDsByDomainID[id] = nil
                    self?.lastLoadError = nil
                    self?.completeOnMain(.success(()), completion: completion)
                }
            }
    }

    private func loadUsers(completion: @escaping (Result<[User], Error>) -> Void) {
        usersCollection.getDocuments(source: .server) { [weak self] usersSnapshot, error in
            guard let self else { return }

            if let error {
                self.debugLog("users collection load failed", error: error)
                completion(.failure(error))
                return
            }

            let userDocuments = usersSnapshot?.documents ?? []
            guard !userDocuments.isEmpty else {
                completion(.success([]))
                return
            }

            self.pinCodesCollection.getDocuments(source: .server) { [weak self] pinSnapshot, error in
                guard let self else { return }

                if let error {
                    self.debugLog("pinCodes collection load failed", error: error)
                    completion(.failure(error))
                    return
                }

                let pinsByUserID = self.makePinsByUserID(from: pinSnapshot?.documents ?? [])
                let loadedUsers = userDocuments.compactMap { document -> User? in
                    let data = document.data()

                    do {
                        let dto = try FirebaseUserDTO(documentID: document.documentID, data: data)
                        return self.makeUser(from: dto, pinCode: pinsByUserID[dto.id] ?? "")
                    } catch {
                        self.debugLog("user list decode failed", error: error, path: document.reference.path, data: data)
                        return nil
                    }
                }
                completion(.success(loadedUsers))
            }
        }
    }

    private var usersCollection: CollectionReference {
        db.collection(Collection.users)
    }

    private var pinCodesCollection: CollectionReference {
        db.collection(Collection.pinCodes)
    }

    private func userReference(firestoreID: String) -> DocumentReference {
        usersCollection.document(firestoreID)
    }

    private func pinCodeReference(_ pinCode: String) -> DocumentReference {
        pinCodesCollection.document(pinCode)
    }

    private func firestoreUserID(for domainID: UUID) -> String {
        firestoreUserIDsByDomainID[domainID] ?? domainID.uuidString
    }

    private func makePINCandidates() -> [String] {
        let cachedPINs = Set(users.map(\.pinCode))

        return Array(Constants.pinRange)
            .map { String(format: "%04d", $0) }
            .filter { !cachedPINs.contains($0) }
            .shuffled()
    }

    private func makePinsByUserID(from documents: [QueryDocumentSnapshot]) -> [String: String] {
        documents.reduce(into: [:]) { result, document in
            let data = document.data()

            do {
                let dto = try FirebasePinCodeDTO(documentID: document.documentID, data: data)
                result[dto.userID] = dto.pinCode
            } catch {
                debugLog("pin list decode failed", error: error, path: document.reference.path, data: data)
            }
        }
    }

    private func makeUser(from dto: FirebaseUserDTO, pinCode: String) -> User? {
        guard let role = UserRole(rawValue: dto.role) else {
            debugLog("role decode failed", data: ["role": dto.role, "userID": dto.id])
            return nil
        }

        guard let accountStatus = UserAccountStatus(rawValue: dto.accountStatus) else {
            debugLog("account status decode failed", data: ["accountStatus": dto.accountStatus, "userID": dto.id])
            return nil
        }

        let domainID = domainUUID(from: dto.id)
        firestoreUserIDsByDomainID[domainID] = dto.id

        return User(
            id: domainID,
            pinCode: pinCode,
            firstName: dto.firstName,
            lastName: dto.lastName,
            role: role,
            accountStatus: accountStatus
        )
    }

    private func domainUUID(from firestoreID: String) -> UUID {
        if let uuid = UUID(uuidString: firestoreID) {
            return uuid
        }

        let bytes = Array(firestoreID.utf8)
        var firstHash: UInt64 = 0xcbf29ce484222325
        var secondHash: UInt64 = 0x84222325cbf29ce4

        for byte in bytes {
            firstHash ^= UInt64(byte)
            firstHash &*= 0x100000001b3

            secondHash ^= UInt64(byte)
            secondHash &*= 0x100000001b3
            secondHash ^= firstHash
        }

        var uuidBytes = withUnsafeBytes(of: firstHash.bigEndian, Array.init)
            + withUnsafeBytes(of: secondHash.bigEndian, Array.init)
        uuidBytes[6] = (uuidBytes[6] & 0x0f) | 0x50
        uuidBytes[8] = (uuidBytes[8] & 0x3f) | 0x80

        return UUID(uuid: (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        ))
    }

    private func makeUserData(
        _ user: User,
        firestoreUserID: String,
        createdAt: Date? = nil,
        updatedAt: Date
    ) -> [String: Any] {
        var data: [String: Any] = [
            "id": firestoreUserID,
            "firstName": user.firstName,
            "lastName": user.lastName,
            "role": user.role.rawValue,
            "accountStatus": user.accountStatus.rawValue,
            "updatedAt": updatedAt
        ]

        if let createdAt {
            data["createdAt"] = createdAt
        }

        return data
    }

    private func makePinCodeData(
        for user: User,
        firestoreUserID: String,
        updatedAt: Date
    ) -> [String: Any] {
        [
            "pinCode": user.pinCode,
            "userID": firestoreUserID,
            "firstNameSnapshot": user.firstName,
            "lastNameSnapshot": user.lastName,
            "roleSnapshot": user.role.rawValue,
            "accountStatusSnapshot": user.accountStatus.rawValue,
            "updatedAt": updatedAt
        ]
    }

    private func upsertCachedUser(_ user: User) {
        guard let index = users.firstIndex(where: { $0.id == user.id }) else {
            users.append(user)
            return
        }

        users[index] = user
    }

    private func completeOnMain<Value>(
        _ result: Result<Value, Error>,
        completion: @escaping (Result<Value, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            completion(result)
        }
    }

    private func debugLog(
        _ _: String,
        error _: Error? = nil,
        path _: String? = nil,
        data _: [String: Any]? = nil
    ) {
    }
}

enum FirebaseUserRepositoryError: LocalizedError {
    case noAvailablePIN
    case emptyTransactionResult
    case inactiveUser
    case invalidPINDocument
    case invalidUserDocument
    case missingPINCode

    var errorDescription: String? {
        switch self {
        case .noAvailablePIN:
            return "Не удалось подобрать свободный PIN."
        case .emptyTransactionResult:
            return "Firebase не вернул созданного сотрудника."
        case .inactiveUser:
            return "Пользователь не активен и не может войти."
        case .invalidPINDocument:
            return "PIN найден, но данные входа повреждены."
        case .invalidUserDocument:
            return "Пользователь найден, но данные учетной записи повреждены."
        case .missingPINCode:
            return "У сотрудника нет PIN-кода."
        }
    }
}
