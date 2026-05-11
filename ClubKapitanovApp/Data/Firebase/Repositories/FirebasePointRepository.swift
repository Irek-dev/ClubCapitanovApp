import FirebaseFirestore
import Foundation

final class FirebasePointRepository: AdminPointRepository {
    private enum Collection {
        static let points = "points"
    }

    private let db: Firestore
    private var points: [Point] = []
    private(set) var lastLoadError: Error?

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func refreshPoints(completion: @escaping () -> Void) {
        db.collection(Collection.points)
            .order(by: "name")
            .getDocuments(source: .server) { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.debugLog("points load failed", error: error)
                    self.points = []
                    self.lastLoadError = error
                    self.completeOnMain(completion)
                    return
                }

                do {
                    self.points = try (snapshot?.documents ?? []).map(self.makePoint)
                    self.lastLoadError = nil
                } catch {
                    self.debugLog("points decode failed", error: error)
                    self.points = []
                    self.lastLoadError = error
                }

                self.completeOnMain(completion)
            }
    }

    func getAvailablePoints(for user: User) -> [Point] {
        let activePoints = points.filter(\.isActive)

        switch user.role {
        case .admin, .staff:
            return activePoints
        case .manager:
            guard let managedPointID = user.managedPointID else {
                return []
            }
            return activePoints.filter { $0.id == managedPointID }
        }
    }

    func ensurePointDocument(_ point: Point, completion: @escaping (Result<Void, Error>) -> Void) {
        performEnsurePointDocument(point) { [weak self] result in
            self?.completeOnMain(result, completion: completion)
        }
    }

    private func makePoint(from document: QueryDocumentSnapshot) throws -> Point {
        let dto = try FirebasePointDTO(documentID: document.documentID, data: document.data())
        guard let id = UUID(uuidString: dto.id) else {
            throw FirebasePointRepositoryError.invalidPointID(dto.id)
        }

        return Point(
            id: id,
            name: dto.name,
            city: dto.city,
            address: dto.address,
            isActive: dto.status == "active"
        )
    }

    private func performEnsurePointDocument(_ point: Point, completion: @escaping (Result<Void, Error>) -> Void) {
        let reference = pointReference(pointID: point.id)

        reference.getDocument(source: .server) { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                self.debugLog("point ensure read failed", error: error, path: reference.path)
                completion(.failure(error))
                return
            }

            let now = Date()
            reference.setData(
                self.makePointData(
                    point,
                    createdAt: snapshot?.exists == true ? nil : now,
                    updatedAt: now
                ),
                merge: true
            ) { error in
                if let error {
                    self.debugLog("point ensure write failed", error: error, path: reference.path)
                    completion(.failure(error))
                    return
                }

                completion(.success(()))
            }
        }
    }

    private func pointReference(pointID: UUID) -> DocumentReference {
        db.collection(Collection.points).document(pointID.uuidString)
    }

    private func makePointData(
        _ point: Point,
        createdAt: Date? = nil,
        updatedAt: Date
    ) -> [String: Any] {
        var data: [String: Any] = [
            "id": point.id.uuidString,
            "name": point.name,
            "city": point.city,
            "address": point.address,
            "status": point.isActive ? "active" : "inactive",
            "updatedAt": updatedAt
        ]

        if let createdAt {
            data["createdAt"] = createdAt
        }

        return data
    }

    private func completeOnMain(_ completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            completion()
        }
    }

    private func completeOnMain<Value>(
        _ result: Result<Value, Error>,
        completion: @escaping (Result<Value, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            completion(result)
        }
    }

    private func debugLog(_ _: String, error _: Error? = nil, path _: String? = nil) {
    }
}

enum FirebasePointRepositoryError: LocalizedError {
    case invalidPointID(String)

    var errorDescription: String? {
        switch self {
        case let .invalidPointID(pointID):
            return "Некорректный id точки в Firestore: \(pointID)"
        }
    }
}
