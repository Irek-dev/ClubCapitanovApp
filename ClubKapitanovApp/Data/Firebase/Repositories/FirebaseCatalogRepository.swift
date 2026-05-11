import FirebaseFirestore
import Foundation

final class FirebaseCatalogRepository: CatalogRepository {
    private enum Collection {
        static let points = "points"
        static let rentalTypes = "rentalTypes"
        static let souvenirs = "souvenirs"
        static let fineTemplates = "fineTemplates"
        static let batteryTypes = "batteryTypes"
    }

    private struct CatalogBundle {
        var rentalTypes: [RentalType] = []
        var souvenirProducts: [SouvenirProduct] = []
        var souvenirQuantityByID: [UUID: Int] = [:]
        var fineTemplates: [FineTemplate] = []
        var batteryItems: [BatteryItem] = []
    }

    private let db: Firestore
    private var cacheByPointID: [UUID: CatalogBundle] = [:]

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func getRentalTypes(pointID: UUID) -> [RentalType] {
        bundle(for: pointID).rentalTypes
    }

    func createRentalType(pointID: UUID, name: String, code: String, durationMinutes: Int, price: Money) -> RentalType {
        var bundle = bundle(for: pointID)
        let rentalType = RentalType(
            pointID: pointID,
            name: name,
            code: code,
            tariffs: [
                RentalTariff(
                    title: "\(durationMinutes) минут",
                    durationMinutes: durationMinutes,
                    price: price,
                    sortOrder: 0
                )
            ],
            payrollRate: Money(kopecks: 0),
            availableQuantity: 0
        )
        bundle.rentalTypes.append(rentalType)
        cacheByPointID[pointID] = bundle
        return rentalType
    }

    func updateRentalType(_ rentalType: RentalType) -> RentalType {
        var bundle = bundle(for: rentalType.pointID)
        if let index = bundle.rentalTypes.firstIndex(where: { $0.id == rentalType.id }) {
            bundle.rentalTypes[index] = rentalType
        } else {
            bundle.rentalTypes.append(rentalType)
        }
        cacheByPointID[rentalType.pointID] = bundle
        return rentalType
    }

    func hideRentalType(id: UUID, pointID: UUID) {
        var bundle = bundle(for: pointID)
        bundle.rentalTypes.removeAll { $0.id == id }
        cacheByPointID[pointID] = bundle
    }

    func getBatteryItems(pointID: UUID) -> [BatteryItem] {
        bundle(for: pointID).batteryItems
    }

    func getRentalAssets(pointID: UUID) -> [RentalAsset] {
        []
    }

    func createRentalAsset(pointID: UUID, rentalTypeID: UUID, displayNumber: String) -> RentalAsset {
        RentalAsset(
            pointID: pointID,
            rentalTypeID: rentalTypeID,
            displayNumber: displayNumber
        )
    }

    func updateRentalAsset(_ asset: RentalAsset) -> RentalAsset {
        asset
    }

    func hideRentalAsset(id: UUID, pointID: UUID) {}

    func getSouvenirProducts(pointID: UUID) -> [SouvenirProduct] {
        bundle(for: pointID).souvenirProducts
    }

    func createSouvenirProduct(pointID: UUID, name: String, price: Money, quantity: Int) -> SouvenirProduct {
        var bundle = bundle(for: pointID)
        let product = SouvenirProduct(
            pointID: pointID,
            name: name,
            price: price,
            sortOrder: bundle.souvenirProducts.count
        )
        bundle.souvenirProducts.append(product)
        bundle.souvenirQuantityByID[product.id] = max(0, quantity)
        cacheByPointID[pointID] = bundle
        return product
    }

    func updateSouvenirProduct(_ product: SouvenirProduct, quantity: Int) -> SouvenirProduct {
        var bundle = bundle(for: product.pointID)
        if let index = bundle.souvenirProducts.firstIndex(where: { $0.id == product.id }) {
            bundle.souvenirProducts[index] = product
        } else {
            bundle.souvenirProducts.append(product)
        }
        bundle.souvenirQuantityByID[product.id] = max(0, quantity)
        cacheByPointID[product.pointID] = bundle
        return product
    }

    func hideSouvenirProduct(id: UUID, pointID: UUID) {
        var bundle = bundle(for: pointID)
        bundle.souvenirProducts.removeAll { $0.id == id }
        bundle.souvenirQuantityByID[id] = nil
        cacheByPointID[pointID] = bundle
    }

    func getSouvenirQuantity(productID: UUID, pointID: UUID) -> Int {
        bundle(for: pointID).souvenirQuantityByID[productID] ?? 0
    }

    func getFineTemplates(pointID: UUID) -> [FineTemplate] {
        bundle(for: pointID).fineTemplates
    }

    func createFineTemplate(pointID: UUID, title: String, amount: Money) -> FineTemplate {
        var bundle = bundle(for: pointID)
        let template = FineTemplate(
            pointID: pointID,
            title: title,
            amount: amount,
            sortOrder: bundle.fineTemplates.count
        )
        bundle.fineTemplates.append(template)
        cacheByPointID[pointID] = bundle
        return template
    }

    func updateFineTemplate(_ template: FineTemplate) -> FineTemplate {
        var bundle = bundle(for: template.pointID)
        if let index = bundle.fineTemplates.firstIndex(where: { $0.id == template.id }) {
            bundle.fineTemplates[index] = template
        } else {
            bundle.fineTemplates.append(template)
        }
        cacheByPointID[template.pointID] = bundle
        return template
    }

    func hideFineTemplate(id: UUID, pointID: UUID) {
        var bundle = bundle(for: pointID)
        bundle.fineTemplates.removeAll { $0.id == id }
        cacheByPointID[pointID] = bundle
    }

    private func bundle(for pointID: UUID) -> CatalogBundle {
        cacheByPointID[pointID] ?? CatalogBundle()
    }
}

extension FirebaseCatalogRepository: CatalogRepositoryCacheRefreshing {
    func refreshCatalog(pointID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        let group = DispatchGroup()
        let lock = NSLock()
        var bundle = CatalogBundle()
        var firstError: Error?

        group.enter()
        loadRentalTypes(pointID: pointID) { result in
            lock.lock()
            if case let .success(rentalTypes) = result {
                bundle.rentalTypes = rentalTypes
            } else if case let .failure(error) = result, firstError == nil {
                firstError = error
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        loadSouvenirs(pointID: pointID) { result in
            lock.lock()
            if case let .success(souvenirs) = result {
                bundle.souvenirProducts = souvenirs.products
                bundle.souvenirQuantityByID = souvenirs.quantityByID
            } else if case let .failure(error) = result, firstError == nil {
                firstError = error
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        loadFineTemplates(pointID: pointID) { result in
            lock.lock()
            if case let .success(fineTemplates) = result {
                bundle.fineTemplates = fineTemplates
            } else if case let .failure(error) = result, firstError == nil {
                firstError = error
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        loadBatteryTypes(pointID: pointID) { result in
            lock.lock()
            if case let .success(batteryItems) = result {
                bundle.batteryItems = batteryItems
            } else if case let .failure(error) = result, firstError == nil {
                firstError = error
            }
            lock.unlock()
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            if let firstError {
                completion(.failure(firstError))
                return
            }

            self?.cacheByPointID[pointID] = bundle
            completion(.success(()))
        }
    }
}

private extension FirebaseCatalogRepository {
    func pointReference(pointID: UUID) -> DocumentReference {
        db.collection(Collection.points).document(pointID.uuidString)
    }

    func loadRentalTypes(pointID: UUID, completion: @escaping (Result<[RentalType], Error>) -> Void) {
        pointReference(pointID: pointID)
            .collection(Collection.rentalTypes)
            .order(by: "sortOrder")
            .getDocuments(source: .server) { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    completion(.failure(error))
                    return
                }

                do {
                    let rentalTypes = try (snapshot?.documents ?? []).map { document in
                        try self.makeRentalType(from: document, pointID: pointID)
                    }
                    completion(.success(rentalTypes))
                } catch {
                    completion(.failure(error))
                }
            }
    }

    func loadSouvenirs(
        pointID: UUID,
        completion: @escaping (Result<(products: [SouvenirProduct], quantityByID: [UUID: Int]), Error>) -> Void
    ) {
        pointReference(pointID: pointID)
            .collection(Collection.souvenirs)
            .order(by: "sortOrder")
            .getDocuments(source: .server) { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    completion(.failure(error))
                    return
                }

                do {
                    let mapped = try (snapshot?.documents ?? []).map { document in
                        try self.makeSouvenir(from: document, pointID: pointID)
                    }
                    let products = mapped.map(\.product)
                    let quantities = Dictionary(uniqueKeysWithValues: mapped.map { ($0.product.id, $0.quantity) })
                    completion(.success((products, quantities)))
                } catch {
                    completion(.failure(error))
                }
            }
    }

    func loadFineTemplates(pointID: UUID, completion: @escaping (Result<[FineTemplate], Error>) -> Void) {
        pointReference(pointID: pointID)
            .collection(Collection.fineTemplates)
            .order(by: "sortOrder")
            .getDocuments(source: .server) { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    completion(.failure(error))
                    return
                }

                do {
                    let templates = try (snapshot?.documents ?? []).map { document in
                        try self.makeFineTemplate(from: document, pointID: pointID)
                    }
                    completion(.success(templates))
                } catch {
                    completion(.failure(error))
                }
            }
    }

    func loadBatteryTypes(pointID: UUID, completion: @escaping (Result<[BatteryItem], Error>) -> Void) {
        pointReference(pointID: pointID)
            .collection(Collection.batteryTypes)
            .order(by: "sortOrder")
            .getDocuments(source: .server) { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    completion(.failure(error))
                    return
                }

                do {
                    let items = try (snapshot?.documents ?? []).map { document in
                        try self.makeBatteryItem(from: document, pointID: pointID)
                    }
                    completion(.success(items))
                } catch {
                    completion(.failure(error))
                }
            }
    }

    func makeRentalType(from document: QueryDocumentSnapshot, pointID: UUID) throws -> RentalType {
        let dto = try FirebaseRentalTypeDTO(documentID: document.documentID, data: document.data())
        return RentalType(
            id: domainUUID(from: dto.id),
            pointID: pointID,
            name: dto.name,
            code: dto.shortCode,
            tariffs: [
                RentalTariff(
                    title: "\(dto.durationMinutes) минут",
                    durationMinutes: dto.durationMinutes,
                    price: Money(kopecks: dto.priceKopecks),
                    sortOrder: 0
                )
            ],
            payrollRate: Money(kopecks: dto.payrollKopecks),
            availableQuantity: dto.stockQuantity
        )
    }

    func makeSouvenir(
        from document: QueryDocumentSnapshot,
        pointID: UUID
    ) throws -> (product: SouvenirProduct, quantity: Int) {
        let dto = try FirebaseSouvenirDTO(documentID: document.documentID, data: document.data())
        let product = SouvenirProduct(
            id: domainUUID(from: dto.id),
            pointID: pointID,
            name: dto.name,
            price: Money(kopecks: dto.priceKopecks),
            sortOrder: dto.sortOrder
        )
        return (product, max(0, dto.stockQuantity))
    }

    func makeFineTemplate(from document: QueryDocumentSnapshot, pointID: UUID) throws -> FineTemplate {
        let dto = try FirebaseFineTemplateDTO(documentID: document.documentID, data: document.data())
        return FineTemplate(
            id: domainUUID(from: dto.id),
            pointID: pointID,
            title: dto.name,
            amount: Money(kopecks: dto.amountKopecks),
            sortOrder: dto.sortOrder
        )
    }

    func makeBatteryItem(from document: QueryDocumentSnapshot, pointID: UUID) throws -> BatteryItem {
        let dto = try FirebaseBatteryDTO(documentID: document.documentID, data: document.data())
        return BatteryItem(
            id: domainUUID(from: dto.id),
            pointID: pointID,
            title: dto.name,
            quantity: dto.stockQuantity
        )
    }

    func domainUUID(from firestoreID: String) -> UUID {
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
}
