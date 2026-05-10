import Foundation

/// Временная in-memory реализация каталогов точки.
///
/// Каталоги генерируются отдельно для каждой точки и кэшируются по `pointID`.
/// Так у разных точек могут отличаться прокат, сувенирка и штрафы уже в локальной
/// реализации. Форма данных похожа на будущий внешний каталог:
/// типы проката приходят вместе с тарифами, а не хранят цену в UI.
final class InMemoryCatalogRepository: CatalogRepository {
    private struct CatalogBundle {
        var rentalTypes: [RentalType]
        var rentalAssets: [RentalAsset]
        var souvenirProducts: [SouvenirProduct]
        var souvenirQuantityByID: [UUID: Int]
        var fineTemplates: [FineTemplate]
    }

    private var catalogByPointID: [UUID: CatalogBundle] = [:]

    func getRentalTypes(pointID: UUID) -> [RentalType] {
        bundle(for: pointID).rentalTypes.filter(\.isActive)
    }

    func createRentalType(pointID: UUID, name: String, code: String, durationMinutes: Int, price: Money) -> RentalType {
        var currentBundle = bundle(for: pointID)
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
            ]
        )
        currentBundle.rentalTypes.append(rentalType)
        catalogByPointID[pointID] = currentBundle
        return rentalType
    }

    func updateRentalType(_ rentalType: RentalType) -> RentalType {
        var currentBundle = bundle(for: rentalType.pointID)
        guard let index = currentBundle.rentalTypes.firstIndex(where: { $0.id == rentalType.id }) else {
            currentBundle.rentalTypes.append(rentalType)
            catalogByPointID[rentalType.pointID] = currentBundle
            return rentalType
        }

        currentBundle.rentalTypes[index] = rentalType
        catalogByPointID[rentalType.pointID] = currentBundle
        return rentalType
    }

    func hideRentalType(id: UUID, pointID: UUID) {
        var currentBundle = bundle(for: pointID)
        guard let index = currentBundle.rentalTypes.firstIndex(where: { $0.id == id }) else {
            return
        }

        let rentalType = currentBundle.rentalTypes[index]
        currentBundle.rentalTypes[index] = RentalType(
            id: rentalType.id,
            pointID: rentalType.pointID,
            name: rentalType.name,
            code: rentalType.code,
            tariffs: rentalType.tariffs,
            isActive: false
        )
        currentBundle.rentalAssets = currentBundle.rentalAssets.map { asset in
            guard asset.rentalTypeID == id else { return asset }
            return RentalAsset(
                id: asset.id,
                pointID: asset.pointID,
                rentalTypeID: asset.rentalTypeID,
                displayNumber: asset.displayNumber,
                isActive: false
            )
        }
        catalogByPointID[pointID] = currentBundle
    }

    func getRentalAssets(pointID: UUID) -> [RentalAsset] {
        bundle(for: pointID).rentalAssets.filter(\.isActive)
    }

    func createRentalAsset(pointID: UUID, rentalTypeID: UUID, displayNumber: String) -> RentalAsset {
        var currentBundle = bundle(for: pointID)
        let asset = RentalAsset(
            pointID: pointID,
            rentalTypeID: rentalTypeID,
            displayNumber: displayNumber
        )
        currentBundle.rentalAssets.append(asset)
        catalogByPointID[pointID] = currentBundle
        return asset
    }

    func updateRentalAsset(_ asset: RentalAsset) -> RentalAsset {
        var currentBundle = bundle(for: asset.pointID)
        guard let index = currentBundle.rentalAssets.firstIndex(where: { $0.id == asset.id }) else {
            currentBundle.rentalAssets.append(asset)
            catalogByPointID[asset.pointID] = currentBundle
            return asset
        }

        currentBundle.rentalAssets[index] = asset
        catalogByPointID[asset.pointID] = currentBundle
        return asset
    }

    func hideRentalAsset(id: UUID, pointID: UUID) {
        var currentBundle = bundle(for: pointID)
        guard let index = currentBundle.rentalAssets.firstIndex(where: { $0.id == id }) else {
            return
        }

        let asset = currentBundle.rentalAssets[index]
        currentBundle.rentalAssets[index] = RentalAsset(
            id: asset.id,
            pointID: asset.pointID,
            rentalTypeID: asset.rentalTypeID,
            displayNumber: asset.displayNumber,
            isActive: false
        )
        catalogByPointID[pointID] = currentBundle
    }

    func getSouvenirProducts(pointID: UUID) -> [SouvenirProduct] {
        bundle(for: pointID)
            .souvenirProducts
            .filter(\.isActive)
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func createSouvenirProduct(pointID: UUID, name: String, price: Money, quantity: Int) -> SouvenirProduct {
        var currentBundle = bundle(for: pointID)
        let product = SouvenirProduct(
            pointID: pointID,
            name: name,
            price: price,
            sortOrder: currentBundle.souvenirProducts.count
        )
        currentBundle.souvenirProducts.append(product)
        currentBundle.souvenirQuantityByID[product.id] = max(0, quantity)
        catalogByPointID[pointID] = currentBundle
        return product
    }

    func updateSouvenirProduct(_ product: SouvenirProduct, quantity: Int) -> SouvenirProduct {
        var currentBundle = bundle(for: product.pointID)
        guard let index = currentBundle.souvenirProducts.firstIndex(where: { $0.id == product.id }) else {
            currentBundle.souvenirProducts.append(product)
            currentBundle.souvenirQuantityByID[product.id] = max(0, quantity)
            catalogByPointID[product.pointID] = currentBundle
            return product
        }

        currentBundle.souvenirProducts[index] = product
        currentBundle.souvenirQuantityByID[product.id] = max(0, quantity)
        catalogByPointID[product.pointID] = currentBundle
        return product
    }

    func hideSouvenirProduct(id: UUID, pointID: UUID) {
        var currentBundle = bundle(for: pointID)
        guard let index = currentBundle.souvenirProducts.firstIndex(where: { $0.id == id }) else {
            return
        }

        let product = currentBundle.souvenirProducts[index]
        currentBundle.souvenirProducts[index] = SouvenirProduct(
            id: product.id,
            pointID: product.pointID,
            name: product.name,
            price: product.price,
            isActive: false,
            sortOrder: product.sortOrder
        )
        catalogByPointID[pointID] = currentBundle
    }

    func getSouvenirQuantity(productID: UUID, pointID: UUID) -> Int {
        bundle(for: pointID).souvenirQuantityByID[productID] ?? 0
    }

    func getFineTemplates(pointID: UUID) -> [FineTemplate] {
        bundle(for: pointID)
            .fineTemplates
            .filter(\.isActive)
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func createFineTemplate(pointID: UUID, title: String, amount: Money) -> FineTemplate {
        var currentBundle = bundle(for: pointID)
        let template = FineTemplate(
            pointID: pointID,
            title: title,
            amount: amount,
            sortOrder: currentBundle.fineTemplates.count
        )
        currentBundle.fineTemplates.append(template)
        catalogByPointID[pointID] = currentBundle
        return template
    }

    func updateFineTemplate(_ template: FineTemplate) -> FineTemplate {
        var currentBundle = bundle(for: template.pointID)
        guard let index = currentBundle.fineTemplates.firstIndex(where: { $0.id == template.id }) else {
            currentBundle.fineTemplates.append(template)
            catalogByPointID[template.pointID] = currentBundle
            return template
        }

        currentBundle.fineTemplates[index] = template
        catalogByPointID[template.pointID] = currentBundle
        return template
    }

    func hideFineTemplate(id: UUID, pointID: UUID) {
        var currentBundle = bundle(for: pointID)
        guard let index = currentBundle.fineTemplates.firstIndex(where: { $0.id == id }) else {
            return
        }

        let template = currentBundle.fineTemplates[index]
        currentBundle.fineTemplates[index] = FineTemplate(
            id: template.id,
            pointID: template.pointID,
            title: template.title,
            amount: template.amount,
            isActive: false,
            sortOrder: template.sortOrder
        )
        catalogByPointID[pointID] = currentBundle
    }

    private func bundle(for pointID: UUID) -> CatalogBundle {
        // Ленивая генерация: пока конкретная точка не открыта, ее каталог не создается.
        // Это упрощает фикстуры и сохраняет стабильные id внутри одной сессии app.
        if let existingBundle = catalogByPointID[pointID] {
            return existingBundle
        }

        let ducksType = RentalType(
            pointID: pointID,
            name: "Утка",
            code: "duck",
            tariffs: makeDefaultRentalTariffs()
        )
        let sailType = RentalType(
            pointID: pointID,
            name: "Парусная яхта",
            code: "sail",
            tariffs: makeDefaultRentalTariffs()
        )
        let boatType = RentalType(
            pointID: pointID,
            name: "Катер",
            code: "boat",
            tariffs: makeDefaultRentalTariffs()
        )
        let fireboatType = RentalType(
            pointID: pointID,
            name: "Пожарник",
            code: "fireboat",
            tariffs: makeDefaultRentalTariffs(price: Money(amount: 750))
        )

        let rentalAssets = [
            "У-01", "У-02", "У-03", "У-04", "У-05", "У-06"
        ].map { RentalAsset(pointID: pointID, rentalTypeID: ducksType.id, displayNumber: $0) } + [
            "ПЯ-01", "ПЯ-02", "ПЯ-03", "ПЯ-04"
        ].map { RentalAsset(pointID: pointID, rentalTypeID: sailType.id, displayNumber: $0) } + [
            "К-01", "К-02", "К-03"
        ].map { RentalAsset(pointID: pointID, rentalTypeID: boatType.id, displayNumber: $0) } + [
            "П-01", "П-02"
        ].map { RentalAsset(pointID: pointID, rentalTypeID: fireboatType.id, displayNumber: $0) }

        let bundle = CatalogBundle(
            rentalTypes: [ducksType, sailType, boatType, fireboatType],
            rentalAssets: rentalAssets,
            souvenirProducts: [
                SouvenirProduct(pointID: pointID, name: "Шапка", price: Money(amount: 500), sortOrder: 0),
                SouvenirProduct(pointID: pointID, name: "Кепка", price: Money(amount: 500), sortOrder: 1),
                SouvenirProduct(pointID: pointID, name: "Брелок", price: Money(amount: 300), sortOrder: 2),
                SouvenirProduct(pointID: pointID, name: "Статуэтка", price: Money(amount: 900), sortOrder: 3),
                SouvenirProduct(pointID: pointID, name: "Веревка", price: Money(amount: 250), sortOrder: 4),
                SouvenirProduct(pointID: pointID, name: "Значок", price: Money(amount: 100), sortOrder: 5),
                SouvenirProduct(pointID: pointID, name: "Батарейка", price: Money(amount: 250), sortOrder: 6),
                SouvenirProduct(pointID: pointID, name: "Утка", price: Money(amount: 400), sortOrder: 7),
                SouvenirProduct(pointID: pointID, name: "Сертификат", price: Money(amount: 1000), sortOrder: 8)
            ],
            souvenirQuantityByID: [:],
            fineTemplates: [
                FineTemplate(pointID: pointID, title: "Утка", amount: Money(amount: 1000), sortOrder: 0),
                FineTemplate(pointID: pointID, title: "Парусник", amount: Money(amount: 3000), sortOrder: 1)
            ]
        )

        var hydratedBundle = bundle
        hydratedBundle.souvenirProducts.forEach { product in
            hydratedBundle.souvenirQuantityByID[product.id] = 0
        }

        catalogByPointID[pointID] = hydratedBundle
        return hydratedBundle
    }

    private func makeDefaultRentalTariffs(price: Money = Money(amount: 350)) -> [RentalTariff] {
        [
            RentalTariff(
                title: "20 минут",
                durationMinutes: 20,
                price: price,
                sortOrder: 0
            )
        ]
    }
}

extension InMemoryCatalogRepository: CatalogRepositoryCacheRefreshing {
    func refreshCatalog(pointID: UUID, completion: @escaping () -> Void) {
        _ = bundle(for: pointID)
        completion()
    }
}
