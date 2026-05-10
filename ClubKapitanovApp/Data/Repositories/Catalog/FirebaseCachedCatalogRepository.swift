import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

final class FirebaseCachedCatalogRepository: CatalogRepository {
    fileprivate struct CatalogCacheBundle {
        var rentalTypes: [RentalType]
        var rentalAssets: [RentalAsset]
        var souvenirProducts: [SouvenirProduct]
        var souvenirQuantityByID: [UUID: Int]
        var fineTemplates: [FineTemplate]
    }

    private let fallbackRepository: CatalogRepository
    private var cacheByPointID: [UUID: CatalogCacheBundle] = [:]
    private var loadedPointIDs: Set<UUID> = []

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    init(fallbackRepository: CatalogRepository = InMemoryCatalogRepository()) {
        self.fallbackRepository = fallbackRepository
    }

    func getRentalTypes(pointID: UUID) -> [RentalType] {
        currentBundle(for: pointID)
            .rentalTypes
            .filter(\.isActive)
    }

    func createRentalType(pointID: UUID, name: String, code: String, durationMinutes: Int, price: Money) -> RentalType {
        var bundle = currentBundle(for: pointID)
        let rentalType = RentalType(
            pointID: pointID,
            name: name,
            code: code,
            tariffs: [
                RentalTariff(
                    durationMinutes: durationMinutes,
                    price: price,
                    sortOrder: 0
                )
            ],
            isActive: true
        )
        bundle.rentalTypes.append(rentalType)
        updateCache(bundle, pointID: pointID)
        return rentalType
    }

    func updateRentalType(_ rentalType: RentalType) -> RentalType {
        var bundle = currentBundle(for: rentalType.pointID)
        if let index = bundle.rentalTypes.firstIndex(where: { $0.id == rentalType.id }) {
            bundle.rentalTypes[index] = rentalType
        } else {
            bundle.rentalTypes.append(rentalType)
        }
        updateCache(bundle, pointID: rentalType.pointID)
        return rentalType
    }

    func hideRentalType(id: UUID, pointID: UUID) {
        var bundle = currentBundle(for: pointID)
        guard let index = bundle.rentalTypes.firstIndex(where: { $0.id == id }) else {
            return
        }

        let rentalType = bundle.rentalTypes[index]
        bundle.rentalTypes[index] = RentalType(
            id: rentalType.id,
            pointID: rentalType.pointID,
            name: rentalType.name,
            code: rentalType.code,
            tariffs: rentalType.tariffs,
            isActive: false
        )
        bundle.rentalAssets = bundle.rentalAssets.map { asset in
            guard asset.rentalTypeID == id else { return asset }
            return RentalAsset(
                id: asset.id,
                pointID: asset.pointID,
                rentalTypeID: asset.rentalTypeID,
                displayNumber: asset.displayNumber,
                isActive: false
            )
        }
        updateCache(bundle, pointID: pointID)
    }

    func getRentalAssets(pointID: UUID) -> [RentalAsset] {
        currentBundle(for: pointID)
            .rentalAssets
            .filter(\.isActive)
            .sorted { $0.displayNumber < $1.displayNumber }
    }

    func createRentalAsset(pointID: UUID, rentalTypeID: UUID, displayNumber: String) -> RentalAsset {
        var bundle = currentBundle(for: pointID)
        let asset = RentalAsset(
            pointID: pointID,
            rentalTypeID: rentalTypeID,
            displayNumber: displayNumber
        )
        bundle.rentalAssets.append(asset)
        updateCache(bundle, pointID: pointID)
        return asset
    }

    func updateRentalAsset(_ asset: RentalAsset) -> RentalAsset {
        var bundle = currentBundle(for: asset.pointID)
        if let index = bundle.rentalAssets.firstIndex(where: { $0.id == asset.id }) {
            bundle.rentalAssets[index] = asset
        } else {
            bundle.rentalAssets.append(asset)
        }
        updateCache(bundle, pointID: asset.pointID)
        return asset
    }

    func hideRentalAsset(id: UUID, pointID: UUID) {
        var bundle = currentBundle(for: pointID)
        guard let index = bundle.rentalAssets.firstIndex(where: { $0.id == id }) else {
            return
        }

        let asset = bundle.rentalAssets[index]
        bundle.rentalAssets[index] = RentalAsset(
            id: asset.id,
            pointID: asset.pointID,
            rentalTypeID: asset.rentalTypeID,
            displayNumber: asset.displayNumber,
            isActive: false
        )
        updateCache(bundle, pointID: pointID)
    }

    func getSouvenirProducts(pointID: UUID) -> [SouvenirProduct] {
        currentBundle(for: pointID)
            .souvenirProducts
            .filter(\.isActive)
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func createSouvenirProduct(pointID: UUID, name: String, price: Money, quantity: Int) -> SouvenirProduct {
        var bundle = currentBundle(for: pointID)
        let product = SouvenirProduct(
            pointID: pointID,
            name: name,
            price: price,
            sortOrder: bundle.souvenirProducts.count
        )
        bundle.souvenirProducts.append(product)
        bundle.souvenirQuantityByID[product.id] = max(0, quantity)
        updateCache(bundle, pointID: pointID)
        return product
    }

    func updateSouvenirProduct(_ product: SouvenirProduct, quantity: Int) -> SouvenirProduct {
        var bundle = currentBundle(for: product.pointID)
        if let index = bundle.souvenirProducts.firstIndex(where: { $0.id == product.id }) {
            bundle.souvenirProducts[index] = product
        } else {
            bundle.souvenirProducts.append(product)
        }
        bundle.souvenirQuantityByID[product.id] = max(0, quantity)
        updateCache(bundle, pointID: product.pointID)
        return product
    }

    func hideSouvenirProduct(id: UUID, pointID: UUID) {
        var bundle = currentBundle(for: pointID)
        guard let index = bundle.souvenirProducts.firstIndex(where: { $0.id == id }) else {
            return
        }

        let product = bundle.souvenirProducts[index]
        bundle.souvenirProducts[index] = SouvenirProduct(
            id: product.id,
            pointID: product.pointID,
            name: product.name,
            price: product.price,
            isActive: false,
            sortOrder: product.sortOrder
        )
        updateCache(bundle, pointID: pointID)
    }

    func getSouvenirQuantity(productID: UUID, pointID: UUID) -> Int {
        currentBundle(for: pointID).souvenirQuantityByID[productID] ?? 0
    }

    func getFineTemplates(pointID: UUID) -> [FineTemplate] {
        currentBundle(for: pointID)
            .fineTemplates
            .filter(\.isActive)
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func createFineTemplate(pointID: UUID, title: String, amount: Money) -> FineTemplate {
        var bundle = currentBundle(for: pointID)
        let template = FineTemplate(
            pointID: pointID,
            title: title,
            amount: amount,
            sortOrder: bundle.fineTemplates.count
        )
        bundle.fineTemplates.append(template)
        updateCache(bundle, pointID: pointID)
        return template
    }

    func updateFineTemplate(_ template: FineTemplate) -> FineTemplate {
        var bundle = currentBundle(for: template.pointID)
        if let index = bundle.fineTemplates.firstIndex(where: { $0.id == template.id }) {
            bundle.fineTemplates[index] = template
        } else {
            bundle.fineTemplates.append(template)
        }
        updateCache(bundle, pointID: template.pointID)
        return template
    }

    func hideFineTemplate(id: UUID, pointID: UUID) {
        var bundle = currentBundle(for: pointID)
        guard let index = bundle.fineTemplates.firstIndex(where: { $0.id == id }) else {
            return
        }

        let template = bundle.fineTemplates[index]
        bundle.fineTemplates[index] = FineTemplate(
            id: template.id,
            pointID: template.pointID,
            title: template.title,
            amount: template.amount,
            isActive: false,
            sortOrder: template.sortOrder
        )
        updateCache(bundle, pointID: pointID)
    }

    private func currentBundle(for pointID: UUID) -> CatalogCacheBundle {
        if let cachedBundle = cacheByPointID[pointID] {
            return cachedBundle
        }

        let souvenirProducts = fallbackRepository.getSouvenirProducts(pointID: pointID)
        let bundle = CatalogCacheBundle(
            rentalTypes: fallbackRepository.getRentalTypes(pointID: pointID),
            rentalAssets: fallbackRepository.getRentalAssets(pointID: pointID),
            souvenirProducts: souvenirProducts,
            souvenirQuantityByID: Dictionary(
                uniqueKeysWithValues: souvenirProducts.map {
                    ($0.id, fallbackRepository.getSouvenirQuantity(productID: $0.id, pointID: pointID))
                }
            ),
            fineTemplates: fallbackRepository.getFineTemplates(pointID: pointID)
        )
        cacheByPointID[pointID] = bundle
        return bundle
    }

    private func updateCache(_ bundle: CatalogCacheBundle, pointID: UUID) {
        cacheByPointID[pointID] = bundle
        loadedPointIDs.insert(pointID)
        persistCatalog(pointID: pointID)
    }
}

extension FirebaseCachedCatalogRepository: CatalogRepositoryCacheRefreshing {
    func refreshCatalog(pointID: UUID, completion: @escaping () -> Void) {
        guard !loadedPointIDs.contains(pointID) else {
            completion()
            return
        }

        #if canImport(FirebaseFirestore)
        catalogDocument(pointID: pointID).getDocument { [weak self] snapshot, _ in
            guard let self else {
                DispatchQueue.main.async { completion() }
                return
            }

            if let data = snapshot?.data(), snapshot?.exists == true {
                self.cacheByPointID[pointID] = self.decodeCatalog(data, pointID: pointID)
            } else {
                self.cacheByPointID[pointID] = self.currentBundle(for: pointID)
                self.persistCatalog(pointID: pointID)
            }

            self.loadedPointIDs.insert(pointID)
            DispatchQueue.main.async { completion() }
        }
        #else
        loadedPointIDs.insert(pointID)
        completion()
        #endif
    }
}

private extension FirebaseCachedCatalogRepository {
    #if canImport(FirebaseFirestore)
    func catalogDocument(pointID: UUID) -> DocumentReference {
        db.collection("pointCatalogs").document(pointID.uuidString)
    }
    #endif

    func persistCatalog(pointID: UUID) {
        #if canImport(FirebaseFirestore)
        guard let bundle = cacheByPointID[pointID] else { return }
        catalogDocument(pointID: pointID).setData(encodeCatalog(bundle), merge: true)
        #endif
    }

    func encodeCatalog(_ bundle: CatalogCacheBundle) -> [String: Any] {
        [
            "rentalTypes": bundle.rentalTypes.map(encodeRentalType),
            "rentalAssets": bundle.rentalAssets.map(encodeRentalAsset),
            "souvenirProducts": bundle.souvenirProducts.map(encodeSouvenirProduct),
            "souvenirQuantityByID": Dictionary(
                uniqueKeysWithValues: bundle.souvenirQuantityByID.map { ($0.key.uuidString, $0.value) }
            ),
            "fineTemplates": bundle.fineTemplates.map(encodeFineTemplate)
        ]
    }

    func decodeCatalog(_ data: [String: Any], pointID: UUID) -> CatalogCacheBundle {
        let rentalTypes = (data["rentalTypes"] as? [[String: Any]] ?? []).compactMap(decodeRentalType)
        let rentalAssets = (data["rentalAssets"] as? [[String: Any]] ?? []).compactMap(decodeRentalAsset)
        let souvenirProducts = (data["souvenirProducts"] as? [[String: Any]] ?? []).compactMap(decodeSouvenirProduct)
        let rawQuantities = data["souvenirQuantityByID"] as? [String: Any] ?? [:]
        let quantities = Dictionary(
            uniqueKeysWithValues: rawQuantities.compactMap { key, value -> (UUID, Int)? in
                guard let id = UUID(uuidString: key), let quantity = int(value) else { return nil }
                return (id, quantity)
            }
        )
        let fineTemplates = (data["fineTemplates"] as? [[String: Any]] ?? []).compactMap(decodeFineTemplate)

        let fallbackBundle = currentBundle(for: pointID)
        return CatalogCacheBundle(
            rentalTypes: rentalTypes.isEmpty ? fallbackBundle.rentalTypes : rentalTypes,
            rentalAssets: rentalAssets.isEmpty ? fallbackBundle.rentalAssets : rentalAssets,
            souvenirProducts: souvenirProducts.isEmpty ? fallbackBundle.souvenirProducts : souvenirProducts,
            souvenirQuantityByID: quantities.isEmpty ? fallbackBundle.souvenirQuantityByID : quantities,
            fineTemplates: fineTemplates.isEmpty ? fallbackBundle.fineTemplates : fineTemplates
        )
    }

    func encodeRentalType(_ rentalType: RentalType) -> [String: Any] {
        [
            "id": rentalType.id.uuidString,
            "pointID": rentalType.pointID.uuidString,
            "name": rentalType.name,
            "code": rentalType.code,
            "tariffs": rentalType.tariffs.map(encodeRentalTariff),
            "isActive": rentalType.isActive
        ]
    }

    func decodeRentalType(_ data: [String: Any]) -> RentalType? {
        guard
            let id = uuid(data["id"]),
            let pointID = uuid(data["pointID"]),
            let name = data["name"] as? String,
            let code = data["code"] as? String
        else {
            return nil
        }

        let tariffs = (data["tariffs"] as? [[String: Any]] ?? []).compactMap(decodeRentalTariff)
        return RentalType(
            id: id,
            pointID: pointID,
            name: name,
            code: code,
            tariffs: tariffs,
            isActive: bool(data["isActive"]) ?? true
        )
    }

    func encodeRentalTariff(_ tariff: RentalTariff) -> [String: Any] {
        [
            "id": tariff.id.uuidString,
            "title": tariff.title,
            "durationMinutes": tariff.durationMinutes,
            "priceKopecks": tariff.price.kopecks,
            "sortOrder": tariff.sortOrder,
            "isActive": tariff.isActive
        ]
    }

    func decodeRentalTariff(_ data: [String: Any]) -> RentalTariff? {
        guard
            let id = uuid(data["id"]),
            let title = data["title"] as? String,
            let durationMinutes = int(data["durationMinutes"]),
            let priceKopecks = int(data["priceKopecks"]),
            let sortOrder = int(data["sortOrder"])
        else {
            return nil
        }

        return RentalTariff(
            id: id,
            title: title,
            durationMinutes: durationMinutes,
            price: Money(kopecks: priceKopecks),
            sortOrder: sortOrder,
            isActive: bool(data["isActive"]) ?? true
        )
    }

    func encodeRentalAsset(_ asset: RentalAsset) -> [String: Any] {
        [
            "id": asset.id.uuidString,
            "pointID": asset.pointID.uuidString,
            "rentalTypeID": asset.rentalTypeID.uuidString,
            "displayNumber": asset.displayNumber,
            "isActive": asset.isActive
        ]
    }

    func decodeRentalAsset(_ data: [String: Any]) -> RentalAsset? {
        guard
            let id = uuid(data["id"]),
            let pointID = uuid(data["pointID"]),
            let rentalTypeID = uuid(data["rentalTypeID"]),
            let displayNumber = data["displayNumber"] as? String
        else {
            return nil
        }

        return RentalAsset(
            id: id,
            pointID: pointID,
            rentalTypeID: rentalTypeID,
            displayNumber: displayNumber,
            isActive: bool(data["isActive"]) ?? true
        )
    }

    func encodeSouvenirProduct(_ product: SouvenirProduct) -> [String: Any] {
        [
            "id": product.id.uuidString,
            "pointID": product.pointID.uuidString,
            "name": product.name,
            "priceKopecks": product.price.kopecks,
            "isActive": product.isActive,
            "sortOrder": product.sortOrder
        ]
    }

    func decodeSouvenirProduct(_ data: [String: Any]) -> SouvenirProduct? {
        guard
            let id = uuid(data["id"]),
            let pointID = uuid(data["pointID"]),
            let name = data["name"] as? String,
            let priceKopecks = int(data["priceKopecks"]),
            let sortOrder = int(data["sortOrder"])
        else {
            return nil
        }

        return SouvenirProduct(
            id: id,
            pointID: pointID,
            name: name,
            price: Money(kopecks: priceKopecks),
            isActive: bool(data["isActive"]) ?? true,
            sortOrder: sortOrder
        )
    }

    func encodeFineTemplate(_ template: FineTemplate) -> [String: Any] {
        [
            "id": template.id.uuidString,
            "pointID": template.pointID.uuidString,
            "title": template.title,
            "amountKopecks": template.amount.kopecks,
            "isActive": template.isActive,
            "sortOrder": template.sortOrder
        ]
    }

    func decodeFineTemplate(_ data: [String: Any]) -> FineTemplate? {
        guard
            let id = uuid(data["id"]),
            let pointID = uuid(data["pointID"]),
            let title = data["title"] as? String,
            let amountKopecks = int(data["amountKopecks"]),
            let sortOrder = int(data["sortOrder"])
        else {
            return nil
        }

        return FineTemplate(
            id: id,
            pointID: pointID,
            title: title,
            amount: Money(kopecks: amountKopecks),
            isActive: bool(data["isActive"]) ?? true,
            sortOrder: sortOrder
        )
    }

    func uuid(_ value: Any?) -> UUID? {
        guard let text = value as? String else { return nil }
        return UUID(uuidString: text)
    }

    func int(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? Int64 {
            return Int(value)
        }
        if let value = value as? Double {
            return Int(value)
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        return nil
    }

    func bool(_ value: Any?) -> Bool? {
        if let value = value as? Bool {
            return value
        }
        if let value = value as? NSNumber {
            return value.boolValue
        }
        return nil
    }
}
