import Foundation

/// Временная in-memory реализация каталогов точки.
///
/// Каталоги генерируются отдельно для каждой точки и кэшируются по `pointID`.
/// Так у разных точек могут отличаться прокат, сувенирка и штрафы уже в локальной
/// реализации. Форма данных похожа на будущий внешний каталог:
/// типы проката приходят вместе с тарифами, а не хранят цену в UI.
final class InMemoryCatalogRepository: CatalogRepository {
    private struct CatalogBundle {
        let rentalTypes: [RentalType]
        let rentalAssets: [RentalAsset]
        let souvenirProducts: [SouvenirProduct]
        let fineTemplates: [FineTemplate]
    }

    private var catalogByPointID: [UUID: CatalogBundle] = [:]

    func getRentalTypes(pointID: UUID) -> [RentalType] {
        bundle(for: pointID).rentalTypes.filter(\.isActive)
    }

    func getRentalAssets(pointID: UUID) -> [RentalAsset] {
        bundle(for: pointID).rentalAssets.filter(\.isActive)
    }

    func getSouvenirProducts(pointID: UUID) -> [SouvenirProduct] {
        bundle(for: pointID)
            .souvenirProducts
            .filter(\.isActive)
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func getFineTemplates(pointID: UUID) -> [FineTemplate] {
        bundle(for: pointID)
            .fineTemplates
            .filter(\.isActive)
            .sorted { $0.sortOrder < $1.sortOrder }
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
            fineTemplates: [
                FineTemplate(pointID: pointID, title: "Утка", amount: Money(amount: 1000), sortOrder: 0),
                FineTemplate(pointID: pointID, title: "Парусник", amount: Money(amount: 3000), sortOrder: 1)
            ]
        )

        catalogByPointID[pointID] = bundle
        return bundle
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
