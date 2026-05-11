import FirebaseFirestore
import Foundation

final class FirebaseAdminPointCatalogRepository: AdminPointCatalogRepository {
    private enum Collection {
        static let points = "points"
        static let rentalTypes = "rentalTypes"
        static let souvenirs = "souvenirs"
        static let fineTemplates = "fineTemplates"
        static let batteryTypes = "batteryTypes"
    }

    private let db: Firestore
    private var pointContextsByID: [UUID: Point] = [:]
    private var rentalTypesByPointID: [UUID: [RentalType]] = [:]
    private var souvenirProductsByPointID: [UUID: [SouvenirProduct]] = [:]
    private var souvenirQuantityByPointID: [UUID: [UUID: Int]] = [:]
    private var fineTemplatesByPointID: [UUID: [FineTemplate]] = [:]
    private var batteryItemsByPointID: [UUID: [BatteryItem]] = [:]
    private var rentalTypeFirestoreIDsByDomainID: [UUID: String] = [:]
    private var rentalTypeSortOrdersByDomainID: [UUID: Int] = [:]
    private var souvenirFirestoreIDsByDomainID: [UUID: String] = [:]
    private var fineTemplateFirestoreIDsByDomainID: [UUID: String] = [:]
    private var batteryFirestoreIDsByDomainID: [UUID: String] = [:]
    private var batterySortOrdersByDomainID: [UUID: Int] = [:]
    private var rentalTypeLoadErrorsByPointID: [UUID: Error] = [:]
    private var souvenirLoadErrorsByPointID: [UUID: Error] = [:]
    private var fineTemplateLoadErrorsByPointID: [UUID: Error] = [:]
    private var batteryLoadErrorsByPointID: [UUID: Error] = [:]

    var lastRentalTypesLoadError: Error? {
        rentalTypeLoadErrorsByPointID.values.first
    }

    var lastSouvenirsLoadError: Error? {
        souvenirLoadErrorsByPointID.values.first
    }

    var lastFineTemplatesLoadError: Error? {
        fineTemplateLoadErrorsByPointID.values.first
    }

    var lastBatteryTypesLoadError: Error? {
        batteryLoadErrorsByPointID.values.first
    }

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func configurePointContext(_ point: Point) {
        pointContextsByID[point.id] = point
    }

    func refreshRentalTypes(pointID: UUID, completion: @escaping () -> Void) {
        ensurePointThen(
            pointID: pointID,
            failureMessage: "rental types point ensure failed",
            onFailure: { [weak self] error in
                self?.rentalTypeLoadErrorsByPointID[pointID] = error
                self?.completeOnMain(completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.rentalTypesCollection(pointID: pointID)
                    .order(by: "sortOrder")
                    .getDocuments(source: .server) { [weak self] snapshot, error in
                        guard let self else { return }

                        if let error {
                            self.debugLog("rental types load failed", error: error, path: self.rentalTypesCollection(pointID: pointID).path)
                            self.rentalTypeLoadErrorsByPointID[pointID] = error
                            self.completeOnMain(completion)
                            return
                        }

                        do {
                            let documents = snapshot?.documents ?? []
                            self.rentalTypesByPointID[pointID] = try documents
                                .map { document in
                                    try self.makeRentalType(from: document, pointID: pointID)
                                }
                                .sorted { first, second in
                                    let firstSortOrder = self.rentalTypeSortOrdersByDomainID[first.id] ?? Int.max
                                    let secondSortOrder = self.rentalTypeSortOrdersByDomainID[second.id] ?? Int.max

                                    if firstSortOrder == secondSortOrder {
                                        return first.name < second.name
                                    }

                                    return firstSortOrder < secondSortOrder
                                }
                            self.rentalTypeLoadErrorsByPointID[pointID] = nil
                        } catch {
                            self.debugLog("rental types decode failed", error: error, path: self.rentalTypesCollection(pointID: pointID).path)
                            self.rentalTypeLoadErrorsByPointID[pointID] = error
                        }

                        self.completeOnMain(completion)
                    }
            }
        )
    }

    func getRentalTypes(pointID: UUID) -> [RentalType] {
        (rentalTypesByPointID[pointID] ?? []).sorted { first, second in
            let firstSortOrder = rentalTypeSortOrdersByDomainID[first.id] ?? Int.max
            let secondSortOrder = rentalTypeSortOrdersByDomainID[second.id] ?? Int.max

            if firstSortOrder == secondSortOrder {
                return first.name < second.name
            }

            return firstSortOrder < secondSortOrder
        }
    }

    func createRentalType(
        pointID: UUID,
        name: String,
        code: String,
        durationMinutes: Int,
        price: Money,
        payrollRate: Money,
        quantity: Int,
        completion: @escaping (Result<RentalType, Error>) -> Void
    ) {
        let id = UUID()
        let firestoreID = id.uuidString
        let sortOrder = nextRentalTypeSortOrder(pointID: pointID)
        let rentalType = RentalType(
            id: id,
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
            payrollRate: payrollRate,
            availableQuantity: quantity
        )
        let now = Date()

        ensurePointThen(
            pointID: pointID,
            failureMessage: "rental type point ensure failed",
            onFailure: { [weak self] error in
                self?.completeOnMain(.failure(error), completion: completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.rentalTypeReference(pointID: pointID, firestoreID: firestoreID)
                    .setData(
                        self.makeRentalTypeData(
                            rentalType,
                            firestoreID: firestoreID,
                            sortOrder: sortOrder,
                            createdAt: now,
                            updatedAt: now
                        )
                    ) { [weak self] error in
                        guard let self else { return }

                        if let error {
                            self.debugLog("rental type create failed", error: error)
                            self.completeOnMain(.failure(error), completion: completion)
                            return
                        }

                        self.rentalTypeFirestoreIDsByDomainID[id] = firestoreID
                        self.upsert(rentalType, sortOrder: sortOrder)
                        self.rentalTypeLoadErrorsByPointID[pointID] = nil
                        self.completeOnMain(.success(rentalType), completion: completion)
                    }
            }
        )
    }

    func updateRentalType(
        _ rentalType: RentalType,
        completion: @escaping (Result<RentalType, Error>) -> Void
    ) {
        let firestoreID = rentalTypeFirestoreID(for: rentalType.id)
        let sortOrder = rentalTypeSortOrdersByDomainID[rentalType.id] ?? nextRentalTypeSortOrder(pointID: rentalType.pointID)
        let now = Date()

        ensurePointThen(
            pointID: rentalType.pointID,
            failureMessage: "rental type point ensure failed",
            onFailure: { [weak self] error in
                self?.completeOnMain(.failure(error), completion: completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.rentalTypeReference(pointID: rentalType.pointID, firestoreID: firestoreID)
                    .setData(
                        self.makeRentalTypeData(
                            rentalType,
                            firestoreID: firestoreID,
                            sortOrder: sortOrder,
                            updatedAt: now
                        ),
                        merge: true
                    ) { [weak self] error in
                        guard let self else { return }

                        if let error {
                            self.debugLog("rental type update failed", error: error)
                            self.completeOnMain(.failure(error), completion: completion)
                            return
                        }

                        self.rentalTypeFirestoreIDsByDomainID[rentalType.id] = firestoreID
                        self.upsert(rentalType, sortOrder: sortOrder)
                        self.rentalTypeLoadErrorsByPointID[rentalType.pointID] = nil
                        self.completeOnMain(.success(rentalType), completion: completion)
                    }
            }
        )
    }

    func deleteRentalType(
        id: UUID,
        pointID: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let firestoreID = rentalTypeFirestoreID(for: id)

        ensurePointThen(
            pointID: pointID,
            failureMessage: "rental type point ensure failed",
            onFailure: { [weak self] error in
                self?.completeOnMain(.failure(error), completion: completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.rentalTypeReference(pointID: pointID, firestoreID: firestoreID).delete { [weak self] error in
                    guard let self else { return }

                    if let error {
                        self.debugLog("rental type delete failed", error: error)
                        self.completeOnMain(.failure(error), completion: completion)
                        return
                    }

                    self.rentalTypesByPointID[pointID]?.removeAll { $0.id == id }
                    self.rentalTypeFirestoreIDsByDomainID[id] = nil
                    self.rentalTypeSortOrdersByDomainID[id] = nil
                    self.rentalTypeLoadErrorsByPointID[pointID] = nil
                    self.completeOnMain(.success(()), completion: completion)
                }
            }
        )
    }

    func refreshSouvenirs(pointID: UUID, completion: @escaping () -> Void) {
        ensurePointThen(
            pointID: pointID,
            failureMessage: "souvenir point ensure failed",
            onFailure: { [weak self] error in
                self?.souvenirLoadErrorsByPointID[pointID] = error
                self?.completeOnMain(completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.souvenirsCollection(pointID: pointID)
                    .order(by: "sortOrder")
                    .getDocuments(source: .server) { [weak self] snapshot, error in
                        guard let self else { return }

                        if let error {
                            self.debugLog("souvenirs load failed", error: error, path: self.souvenirsCollection(pointID: pointID).path)
                            self.souvenirLoadErrorsByPointID[pointID] = error
                            self.completeOnMain(completion)
                            return
                        }

                        do {
                            let documents = snapshot?.documents ?? []
                            let mapped = try documents.map { document in
                                try self.makeSouvenirProduct(from: document, pointID: pointID)
                            }
                            self.souvenirProductsByPointID[pointID] = mapped
                                .map(\.product)
                                .sorted { $0.sortOrder < $1.sortOrder }
                            self.souvenirQuantityByPointID[pointID] = mapped.reduce(into: [:]) { result, item in
                                result[item.product.id] = item.quantity
                            }
                            self.souvenirLoadErrorsByPointID[pointID] = nil
                        } catch {
                            self.debugLog("souvenirs decode failed", error: error, path: self.souvenirsCollection(pointID: pointID).path)
                            self.souvenirLoadErrorsByPointID[pointID] = error
                        }

                        self.completeOnMain(completion)
                    }
            }
        )
    }

    func getSouvenirProducts(pointID: UUID) -> [SouvenirProduct] {
        (souvenirProductsByPointID[pointID] ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func getSouvenirQuantity(productID: UUID, pointID: UUID) -> Int {
        souvenirQuantityByPointID[pointID]?[productID] ?? 0
    }

    func createSouvenirProduct(
        pointID: UUID,
        name: String,
        price: Money,
        quantity: Int,
        completion: @escaping (Result<SouvenirProduct, Error>) -> Void
    ) {
        let id = UUID()
        let firestoreID = id.uuidString
        let sortOrder = nextSouvenirSortOrder(pointID: pointID)
        let product = SouvenirProduct(
            id: id,
            pointID: pointID,
            name: name,
            price: price,
            sortOrder: sortOrder
        )
        let now = Date()

        ensurePointThen(
            pointID: pointID,
            failureMessage: "souvenir point ensure failed",
            onFailure: { [weak self] error in
                self?.completeOnMain(.failure(error), completion: completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.souvenirReference(pointID: pointID, firestoreID: firestoreID)
                    .setData(
                        self.makeSouvenirData(
                            product,
                            firestoreID: firestoreID,
                            quantity: quantity,
                            createdAt: now,
                            updatedAt: now
                        )
                    ) { [weak self] error in
                        guard let self else { return }

                        if let error {
                            self.debugLog("souvenir create failed", error: error)
                            self.completeOnMain(.failure(error), completion: completion)
                            return
                        }

                        self.souvenirFirestoreIDsByDomainID[id] = firestoreID
                        self.upsert(product, quantity: quantity)
                        self.souvenirLoadErrorsByPointID[pointID] = nil
                        self.completeOnMain(.success(product), completion: completion)
                    }
            }
        )
    }

    func updateSouvenirProduct(
        _ product: SouvenirProduct,
        quantity: Int,
        completion: @escaping (Result<SouvenirProduct, Error>) -> Void
    ) {
        let firestoreID = souvenirFirestoreID(for: product.id)
        let now = Date()

        ensurePointThen(
            pointID: product.pointID,
            failureMessage: "souvenir point ensure failed",
            onFailure: { [weak self] error in
                self?.completeOnMain(.failure(error), completion: completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.souvenirReference(pointID: product.pointID, firestoreID: firestoreID)
                    .setData(
                        self.makeSouvenirData(
                            product,
                            firestoreID: firestoreID,
                            quantity: quantity,
                            updatedAt: now
                        ),
                        merge: true
                    ) { [weak self] error in
                        guard let self else { return }

                        if let error {
                            self.debugLog("souvenir update failed", error: error)
                            self.completeOnMain(.failure(error), completion: completion)
                            return
                        }

                        self.souvenirFirestoreIDsByDomainID[product.id] = firestoreID
                        self.upsert(product, quantity: quantity)
                        self.souvenirLoadErrorsByPointID[product.pointID] = nil
                        self.completeOnMain(.success(product), completion: completion)
                    }
            }
        )
    }

    func deleteSouvenirProduct(
        id: UUID,
        pointID: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let firestoreID = souvenirFirestoreID(for: id)

        ensurePointThen(
            pointID: pointID,
            failureMessage: "souvenir point ensure failed",
            onFailure: { [weak self] error in
                self?.completeOnMain(.failure(error), completion: completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.souvenirReference(pointID: pointID, firestoreID: firestoreID).delete { [weak self] error in
                    guard let self else { return }

                    if let error {
                        self.debugLog("souvenir delete failed", error: error)
                        self.completeOnMain(.failure(error), completion: completion)
                        return
                    }

                    self.souvenirProductsByPointID[pointID]?.removeAll { $0.id == id }
                    self.souvenirQuantityByPointID[pointID]?[id] = nil
                    self.souvenirFirestoreIDsByDomainID[id] = nil
                    self.souvenirLoadErrorsByPointID[pointID] = nil
                    self.completeOnMain(.success(()), completion: completion)
                }
            }
        )
    }

    func refreshFineTemplates(pointID: UUID, completion: @escaping () -> Void) {
        ensurePointThen(
            pointID: pointID,
            failureMessage: "fine template point ensure failed",
            onFailure: { [weak self] error in
                self?.fineTemplateLoadErrorsByPointID[pointID] = error
                self?.completeOnMain(completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.fineTemplatesCollection(pointID: pointID)
                    .order(by: "sortOrder")
                    .getDocuments(source: .server) { [weak self] snapshot, error in
                        guard let self else { return }

                        if let error {
                            self.debugLog("fine templates load failed", error: error, path: self.fineTemplatesCollection(pointID: pointID).path)
                            self.fineTemplateLoadErrorsByPointID[pointID] = error
                            self.completeOnMain(completion)
                            return
                        }

                        do {
                            let documents = snapshot?.documents ?? []
                            self.fineTemplatesByPointID[pointID] = try documents.map { document in
                                try self.makeFineTemplate(from: document, pointID: pointID)
                            }
                            self.fineTemplateLoadErrorsByPointID[pointID] = nil
                        } catch {
                            self.debugLog("fine templates decode failed", error: error, path: self.fineTemplatesCollection(pointID: pointID).path)
                            self.fineTemplateLoadErrorsByPointID[pointID] = error
                        }

                        self.completeOnMain(completion)
                    }
            }
        )
    }

    func getFineTemplates(pointID: UUID) -> [FineTemplate] {
        (fineTemplatesByPointID[pointID] ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func createFineTemplate(
        pointID: UUID,
        title: String,
        amount: Money,
        completion: @escaping (Result<FineTemplate, Error>) -> Void
    ) {
        let id = UUID()
        let firestoreID = id.uuidString
        let sortOrder = nextFineTemplateSortOrder(pointID: pointID)
        let template = FineTemplate(
            id: id,
            pointID: pointID,
            title: title,
            amount: amount,
            sortOrder: sortOrder
        )
        let now = Date()

        ensurePointThen(
            pointID: pointID,
            failureMessage: "fine template point ensure failed",
            onFailure: { [weak self] error in
                self?.completeOnMain(.failure(error), completion: completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.fineTemplateReference(pointID: pointID, firestoreID: firestoreID)
                    .setData(
                        self.makeFineTemplateData(
                            template,
                            firestoreID: firestoreID,
                            createdAt: now,
                            updatedAt: now
                        )
                    ) { [weak self] error in
                        guard let self else { return }

                        if let error {
                            self.debugLog("fine template create failed", error: error)
                            self.completeOnMain(.failure(error), completion: completion)
                            return
                        }

                        self.fineTemplateFirestoreIDsByDomainID[id] = firestoreID
                        self.upsert(template)
                        self.fineTemplateLoadErrorsByPointID[pointID] = nil
                        self.completeOnMain(.success(template), completion: completion)
                    }
            }
        )
    }

    func updateFineTemplate(
        _ template: FineTemplate,
        completion: @escaping (Result<FineTemplate, Error>) -> Void
    ) {
        let firestoreID = fineTemplateFirestoreID(for: template.id)
        let now = Date()

        ensurePointThen(
            pointID: template.pointID,
            failureMessage: "fine template point ensure failed",
            onFailure: { [weak self] error in
                self?.completeOnMain(.failure(error), completion: completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.fineTemplateReference(pointID: template.pointID, firestoreID: firestoreID)
                    .setData(
                        self.makeFineTemplateData(
                            template,
                            firestoreID: firestoreID,
                            updatedAt: now
                        ),
                        merge: true
                    ) { [weak self] error in
                        guard let self else { return }

                        if let error {
                            self.debugLog("fine template update failed", error: error)
                            self.completeOnMain(.failure(error), completion: completion)
                            return
                        }

                        self.fineTemplateFirestoreIDsByDomainID[template.id] = firestoreID
                        self.upsert(template)
                        self.fineTemplateLoadErrorsByPointID[template.pointID] = nil
                        self.completeOnMain(.success(template), completion: completion)
                    }
            }
        )
    }

    func deleteFineTemplate(
        id: UUID,
        pointID: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let firestoreID = fineTemplateFirestoreID(for: id)

        ensurePointThen(
            pointID: pointID,
            failureMessage: "fine template point ensure failed",
            onFailure: { [weak self] error in
                self?.completeOnMain(.failure(error), completion: completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.fineTemplateReference(pointID: pointID, firestoreID: firestoreID).delete { [weak self] error in
                    guard let self else { return }

                    if let error {
                        self.debugLog("fine template delete failed", error: error)
                        self.completeOnMain(.failure(error), completion: completion)
                        return
                    }

                    self.fineTemplatesByPointID[pointID]?.removeAll { $0.id == id }
                    self.fineTemplateFirestoreIDsByDomainID[id] = nil
                    self.fineTemplateLoadErrorsByPointID[pointID] = nil
                    self.completeOnMain(.success(()), completion: completion)
                }
            }
        )
    }

    func refreshBatteryTypes(pointID: UUID, completion: @escaping () -> Void) {
        ensurePointThen(
            pointID: pointID,
            failureMessage: "battery type point ensure failed",
            onFailure: { [weak self] error in
                self?.batteryLoadErrorsByPointID[pointID] = error
                self?.completeOnMain(completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.batteryTypesCollection(pointID: pointID)
                    .order(by: "sortOrder")
                    .getDocuments(source: .server) { [weak self] snapshot, error in
                        guard let self else { return }

                        if let error {
                            self.debugLog("battery types load failed", error: error, path: self.batteryTypesCollection(pointID: pointID).path)
                            self.batteryLoadErrorsByPointID[pointID] = error
                            self.completeOnMain(completion)
                            return
                        }

                        do {
                            let documents = snapshot?.documents ?? []
                            let mapped = try documents.map { document in
                                try self.makeBatteryItem(from: document, pointID: pointID)
                            }
                            self.batteryItemsByPointID[pointID] = mapped
                                .sorted { $0.sortOrder < $1.sortOrder }
                                .map { $0.item }
                            self.batteryLoadErrorsByPointID[pointID] = nil
                        } catch {
                            self.debugLog("battery types decode failed", error: error, path: self.batteryTypesCollection(pointID: pointID).path)
                            self.batteryLoadErrorsByPointID[pointID] = error
                        }

                        self.completeOnMain(completion)
                    }
            }
        )
    }

    func getBatteryItems(pointID: UUID) -> [BatteryItem] {
        (batteryItemsByPointID[pointID] ?? []).sorted { first, second in
            let firstSortOrder = batterySortOrdersByDomainID[first.id] ?? Int.max
            let secondSortOrder = batterySortOrdersByDomainID[second.id] ?? Int.max

            if firstSortOrder == secondSortOrder {
                return first.title < second.title
            }

            return firstSortOrder < secondSortOrder
        }
    }

    func createBatteryItem(
        pointID: UUID,
        title: String,
        quantity: Int,
        completion: @escaping (Result<BatteryItem, Error>) -> Void
    ) {
        let id = UUID()
        let firestoreID = id.uuidString
        let sortOrder = nextBatterySortOrder(pointID: pointID)
        let item = BatteryItem(
            id: id,
            pointID: pointID,
            title: title,
            quantity: quantity
        )
        let now = Date()

        ensurePointThen(
            pointID: pointID,
            failureMessage: "battery type point ensure failed",
            onFailure: { [weak self] error in
                self?.completeOnMain(.failure(error), completion: completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.batteryTypeReference(pointID: pointID, firestoreID: firestoreID)
                    .setData(
                        self.makeBatteryData(
                            item,
                            firestoreID: firestoreID,
                            sortOrder: sortOrder,
                            createdAt: now,
                            updatedAt: now
                        )
                    ) { [weak self] error in
                        guard let self else { return }

                        if let error {
                            self.debugLog("battery type create failed", error: error)
                            self.completeOnMain(.failure(error), completion: completion)
                            return
                        }

                        self.batteryFirestoreIDsByDomainID[id] = firestoreID
                        self.upsert(item, sortOrder: sortOrder)
                        self.batteryLoadErrorsByPointID[pointID] = nil
                        self.completeOnMain(.success(item), completion: completion)
                    }
            }
        )
    }

    func updateBatteryItem(
        _ item: BatteryItem,
        completion: @escaping (Result<BatteryItem, Error>) -> Void
    ) {
        let firestoreID = batteryFirestoreID(for: item.id)
        let sortOrder = batterySortOrdersByDomainID[item.id] ?? nextBatterySortOrder(pointID: item.pointID)
        let now = Date()

        ensurePointThen(
            pointID: item.pointID,
            failureMessage: "battery type point ensure failed",
            onFailure: { [weak self] error in
                self?.completeOnMain(.failure(error), completion: completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.batteryTypeReference(pointID: item.pointID, firestoreID: firestoreID)
                    .setData(
                        self.makeBatteryData(
                            item,
                            firestoreID: firestoreID,
                            sortOrder: sortOrder,
                            updatedAt: now
                        ),
                        merge: true
                    ) { [weak self] error in
                        guard let self else { return }

                        if let error {
                            self.debugLog("battery type update failed", error: error)
                            self.completeOnMain(.failure(error), completion: completion)
                            return
                        }

                        self.batteryFirestoreIDsByDomainID[item.id] = firestoreID
                        self.upsert(item, sortOrder: sortOrder)
                        self.batteryLoadErrorsByPointID[item.pointID] = nil
                        self.completeOnMain(.success(item), completion: completion)
                    }
            }
        )
    }

    func deleteBatteryItem(
        id: UUID,
        pointID: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let firestoreID = batteryFirestoreID(for: id)

        ensurePointThen(
            pointID: pointID,
            failureMessage: "battery type point ensure failed",
            onFailure: { [weak self] error in
                self?.completeOnMain(.failure(error), completion: completion)
            },
            operation: { [weak self] in
                guard let self else { return }

                self.batteryTypeReference(pointID: pointID, firestoreID: firestoreID).delete { [weak self] error in
                    guard let self else { return }

                    if let error {
                        self.debugLog("battery type delete failed", error: error)
                        self.completeOnMain(.failure(error), completion: completion)
                        return
                    }

                    self.batteryItemsByPointID[pointID]?.removeAll { $0.id == id }
                    self.batteryFirestoreIDsByDomainID[id] = nil
                    self.batterySortOrdersByDomainID[id] = nil
                    self.batteryLoadErrorsByPointID[pointID] = nil
                    self.completeOnMain(.success(()), completion: completion)
                }
            }
        )
    }

    private func pointReference(pointID: UUID) -> DocumentReference {
        db.collection(Collection.points).document(pointID.uuidString)
    }

    private func ensurePointThen(
        pointID: UUID,
        failureMessage: String,
        onFailure: @escaping (Error) -> Void,
        operation: @escaping () -> Void
    ) {
        ensurePointDocument(pointID: pointID) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                operation()
            case let .failure(error):
                self.debugLog(failureMessage, error: error, path: self.pointReference(pointID: pointID).path)
                onFailure(error)
            }
        }
    }

    private func ensurePointDocument(
        pointID: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let point = pointContextsByID[pointID] else {
            completion(.failure(FirebaseAdminPointCatalogRepositoryError.missingPointContext(pointID)))
            return
        }

        let reference = pointReference(pointID: pointID)
        reference.getDocument(source: .server) { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
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
                    completion(.failure(error))
                    return
                }

                completion(.success(()))
            }
        }
    }

    private func souvenirsCollection(pointID: UUID) -> CollectionReference {
        pointReference(pointID: pointID).collection(Collection.souvenirs)
    }

    private func rentalTypesCollection(pointID: UUID) -> CollectionReference {
        pointReference(pointID: pointID).collection(Collection.rentalTypes)
    }

    private func fineTemplatesCollection(pointID: UUID) -> CollectionReference {
        pointReference(pointID: pointID).collection(Collection.fineTemplates)
    }

    private func batteryTypesCollection(pointID: UUID) -> CollectionReference {
        pointReference(pointID: pointID).collection(Collection.batteryTypes)
    }

    private func souvenirReference(pointID: UUID, firestoreID: String) -> DocumentReference {
        souvenirsCollection(pointID: pointID).document(firestoreID)
    }

    private func rentalTypeReference(pointID: UUID, firestoreID: String) -> DocumentReference {
        rentalTypesCollection(pointID: pointID).document(firestoreID)
    }

    private func fineTemplateReference(pointID: UUID, firestoreID: String) -> DocumentReference {
        fineTemplatesCollection(pointID: pointID).document(firestoreID)
    }

    private func batteryTypeReference(pointID: UUID, firestoreID: String) -> DocumentReference {
        batteryTypesCollection(pointID: pointID).document(firestoreID)
    }

    private func makeRentalType(
        from document: QueryDocumentSnapshot,
        pointID: UUID
    ) throws -> RentalType {
        let dto = try FirebaseRentalTypeDTO(documentID: document.documentID, data: document.data())
        let domainID = domainUUID(from: dto.id)
        rentalTypeFirestoreIDsByDomainID[domainID] = dto.id
        rentalTypeSortOrdersByDomainID[domainID] = dto.sortOrder

        return RentalType(
            id: domainID,
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

    private func makeSouvenirProduct(
        from document: QueryDocumentSnapshot,
        pointID: UUID
    ) throws -> (product: SouvenirProduct, quantity: Int) {
        let dto = try FirebaseSouvenirDTO(documentID: document.documentID, data: document.data())
        let domainID = domainUUID(from: dto.id)
        souvenirFirestoreIDsByDomainID[domainID] = dto.id

        let product = SouvenirProduct(
            id: domainID,
            pointID: pointID,
            name: dto.name,
            price: Money(kopecks: dto.priceKopecks),
            sortOrder: dto.sortOrder
        )
        return (product, max(0, dto.stockQuantity))
    }

    private func makeFineTemplate(
        from document: QueryDocumentSnapshot,
        pointID: UUID
    ) throws -> FineTemplate {
        let dto = try FirebaseFineTemplateDTO(documentID: document.documentID, data: document.data())
        let domainID = domainUUID(from: dto.id)
        fineTemplateFirestoreIDsByDomainID[domainID] = dto.id

        return FineTemplate(
            id: domainID,
            pointID: pointID,
            title: dto.name,
            amount: Money(kopecks: dto.amountKopecks),
            sortOrder: dto.sortOrder
        )
    }

    private func makeBatteryItem(
        from document: QueryDocumentSnapshot,
        pointID: UUID
    ) throws -> (item: BatteryItem, sortOrder: Int) {
        let dto = try FirebaseBatteryDTO(documentID: document.documentID, data: document.data())
        let domainID = domainUUID(from: dto.id)
        batteryFirestoreIDsByDomainID[domainID] = dto.id
        batterySortOrdersByDomainID[domainID] = dto.sortOrder

        return (
            BatteryItem(
                id: domainID,
                pointID: pointID,
                title: dto.name,
                quantity: dto.stockQuantity
            ),
            dto.sortOrder
        )
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

    private func makeRentalTypeData(
        _ rentalType: RentalType,
        firestoreID: String,
        sortOrder: Int,
        createdAt: Date? = nil,
        updatedAt: Date
    ) -> [String: Any] {
        let tariff = rentalType.defaultTariff
        var data: [String: Any] = [
            "id": firestoreID,
            "name": rentalType.name,
            "shortCode": rentalType.code,
            "priceKopecks": tariff?.price.kopecks ?? 0,
            "durationMinutes": tariff?.durationMinutes ?? 0,
            "payrollKopecks": rentalType.payrollRate.kopecks,
            "stockQuantity": rentalType.availableQuantity,
            "sortOrder": sortOrder,
            "updatedAt": updatedAt
        ]

        if let createdAt {
            data["createdAt"] = createdAt
        }

        return data
    }

    private func makeSouvenirData(
        _ product: SouvenirProduct,
        firestoreID: String,
        quantity: Int,
        createdAt: Date? = nil,
        updatedAt: Date
    ) -> [String: Any] {
        var data: [String: Any] = [
            "id": firestoreID,
            "name": product.name,
            "priceKopecks": product.price.kopecks,
            "stockQuantity": max(0, quantity),
            "sortOrder": product.sortOrder,
            "updatedAt": updatedAt
        ]

        if let createdAt {
            data["createdAt"] = createdAt
        }

        return data
    }

    private func makeFineTemplateData(
        _ template: FineTemplate,
        firestoreID: String,
        createdAt: Date? = nil,
        updatedAt: Date
    ) -> [String: Any] {
        var data: [String: Any] = [
            "id": firestoreID,
            "name": template.title,
            "amountKopecks": template.amount.kopecks,
            "sortOrder": template.sortOrder,
            "updatedAt": updatedAt
        ]

        if let createdAt {
            data["createdAt"] = createdAt
        }

        return data
    }

    private func makeBatteryData(
        _ item: BatteryItem,
        firestoreID: String,
        sortOrder: Int,
        createdAt: Date? = nil,
        updatedAt: Date
    ) -> [String: Any] {
        var data: [String: Any] = [
            "id": firestoreID,
            "name": item.title,
            "stockQuantity": item.quantity,
            "sortOrder": sortOrder,
            "updatedAt": updatedAt
        ]

        if let createdAt {
            data["createdAt"] = createdAt
        }

        return data
    }

    private func rentalTypeFirestoreID(for domainID: UUID) -> String {
        rentalTypeFirestoreIDsByDomainID[domainID] ?? domainID.uuidString
    }

    private func souvenirFirestoreID(for domainID: UUID) -> String {
        souvenirFirestoreIDsByDomainID[domainID] ?? domainID.uuidString
    }

    private func fineTemplateFirestoreID(for domainID: UUID) -> String {
        fineTemplateFirestoreIDsByDomainID[domainID] ?? domainID.uuidString
    }

    private func batteryFirestoreID(for domainID: UUID) -> String {
        batteryFirestoreIDsByDomainID[domainID] ?? domainID.uuidString
    }

    private func nextRentalTypeSortOrder(pointID: UUID) -> Int {
        let rentalTypes = rentalTypesByPointID[pointID] ?? []
        let highestSortOrder = rentalTypes
            .compactMap { rentalTypeSortOrdersByDomainID[$0.id] }
            .max()

        return (highestSortOrder ?? (rentalTypes.count - 1)) + 1
    }

    private func nextSouvenirSortOrder(pointID: UUID) -> Int {
        ((souvenirProductsByPointID[pointID] ?? []).map(\.sortOrder).max() ?? -1) + 1
    }

    private func nextFineTemplateSortOrder(pointID: UUID) -> Int {
        ((fineTemplatesByPointID[pointID] ?? []).map(\.sortOrder).max() ?? -1) + 1
    }

    private func nextBatterySortOrder(pointID: UUID) -> Int {
        let items = batteryItemsByPointID[pointID] ?? []
        let highestSortOrder = items
            .compactMap { batterySortOrdersByDomainID[$0.id] }
            .max()

        return (highestSortOrder ?? (items.count - 1)) + 1
    }

    private func upsert(_ rentalType: RentalType, sortOrder: Int) {
        var rentalTypes = rentalTypesByPointID[rentalType.pointID] ?? []
        if let index = rentalTypes.firstIndex(where: { $0.id == rentalType.id }) {
            rentalTypes[index] = rentalType
        } else {
            rentalTypes.append(rentalType)
        }

        rentalTypeSortOrdersByDomainID[rentalType.id] = sortOrder
        rentalTypesByPointID[rentalType.pointID] = rentalTypes.sorted { first, second in
            let firstSortOrder = rentalTypeSortOrdersByDomainID[first.id] ?? Int.max
            let secondSortOrder = rentalTypeSortOrdersByDomainID[second.id] ?? Int.max

            if firstSortOrder == secondSortOrder {
                return first.name < second.name
            }

            return firstSortOrder < secondSortOrder
        }
    }

    private func upsert(_ product: SouvenirProduct, quantity: Int) {
        var products = souvenirProductsByPointID[product.pointID] ?? []
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
        } else {
            products.append(product)
        }

        souvenirProductsByPointID[product.pointID] = products.sorted { $0.sortOrder < $1.sortOrder }
        var quantities = souvenirQuantityByPointID[product.pointID] ?? [:]
        quantities[product.id] = max(0, quantity)
        souvenirQuantityByPointID[product.pointID] = quantities
    }

    private func upsert(_ template: FineTemplate) {
        var templates = fineTemplatesByPointID[template.pointID] ?? []
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }

        fineTemplatesByPointID[template.pointID] = templates.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func upsert(_ item: BatteryItem, sortOrder: Int) {
        var items = batteryItemsByPointID[item.pointID] ?? []
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }

        batterySortOrdersByDomainID[item.id] = sortOrder
        batteryItemsByPointID[item.pointID] = items.sorted { first, second in
            let firstSortOrder = batterySortOrdersByDomainID[first.id] ?? Int.max
            let secondSortOrder = batterySortOrdersByDomainID[second.id] ?? Int.max

            if firstSortOrder == secondSortOrder {
                return first.title < second.title
            }

            return firstSortOrder < secondSortOrder
        }
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

enum FirebaseAdminPointCatalogRepositoryError: LocalizedError {
    case missingPointContext(UUID)

    var errorDescription: String? {
        switch self {
        case let .missingPointContext(pointID):
            return "Нет данных точки \(pointID.uuidString) для создания документа points."
        }
    }
}
