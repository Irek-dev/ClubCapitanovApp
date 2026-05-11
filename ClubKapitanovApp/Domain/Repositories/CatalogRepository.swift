import Foundation

/// Абстракция каталогов точки: типы проката, тарифы, единицы проката, сувенирка и штрафы.
///
/// UI получает каталоги через протокол, поэтому кнопки в workspace не хардкодят
/// ассортимент и цены. При подключении постоянного storage или backend достаточно
/// заменить реализацию репозитория и mapper'ы в `Data`.
protocol CatalogRepository {
    func getRentalTypes(pointID: UUID) -> [RentalType]
    func createRentalType(pointID: UUID, name: String, code: String, durationMinutes: Int, price: Money) -> RentalType
    func updateRentalType(_ rentalType: RentalType) -> RentalType
    func hideRentalType(id: UUID, pointID: UUID)
    func getBatteryItems(pointID: UUID) -> [BatteryItem]

    func getRentalAssets(pointID: UUID) -> [RentalAsset]
    func createRentalAsset(pointID: UUID, rentalTypeID: UUID, displayNumber: String) -> RentalAsset
    func updateRentalAsset(_ asset: RentalAsset) -> RentalAsset
    func hideRentalAsset(id: UUID, pointID: UUID)

    func getSouvenirProducts(pointID: UUID) -> [SouvenirProduct]
    func createSouvenirProduct(pointID: UUID, name: String, price: Money, quantity: Int) -> SouvenirProduct
    func updateSouvenirProduct(_ product: SouvenirProduct, quantity: Int) -> SouvenirProduct
    func hideSouvenirProduct(id: UUID, pointID: UUID)
    func getSouvenirQuantity(productID: UUID, pointID: UUID) -> Int

    func getFineTemplates(pointID: UUID) -> [FineTemplate]
    func createFineTemplate(pointID: UUID, title: String, amount: Money) -> FineTemplate
    func updateFineTemplate(_ template: FineTemplate) -> FineTemplate
    func hideFineTemplate(id: UUID, pointID: UUID)
}

protocol CatalogRepositoryCacheRefreshing {
    func refreshCatalog(pointID: UUID, completion: @escaping (Result<Void, Error>) -> Void)
}

protocol AdminCatalogRepository {
    func deleteRentalType(id: UUID, pointID: UUID)
    func deleteSouvenirProduct(id: UUID, pointID: UUID)
    func deleteFineTemplate(id: UUID, pointID: UUID)

    func getBatteryItems(pointID: UUID) -> [BatteryItem]
    func createBatteryItem(pointID: UUID, title: String, quantity: Int) -> BatteryItem
    func updateBatteryItem(_ item: BatteryItem) -> BatteryItem
    func deleteBatteryItem(id: UUID, pointID: UUID)
}

protocol AdminPointCatalogRepository: AnyObject {
    var lastRentalTypesLoadError: Error? { get }
    var lastSouvenirsLoadError: Error? { get }
    var lastFineTemplatesLoadError: Error? { get }
    var lastBatteryTypesLoadError: Error? { get }

    func configurePointContext(_ point: Point)

    func refreshRentalTypes(pointID: UUID, completion: @escaping () -> Void)
    func getRentalTypes(pointID: UUID) -> [RentalType]
    func createRentalType(
        pointID: UUID,
        name: String,
        code: String,
        durationMinutes: Int,
        price: Money,
        payrollRate: Money,
        quantity: Int,
        completion: @escaping (Result<RentalType, Error>) -> Void
    )
    func updateRentalType(
        _ rentalType: RentalType,
        completion: @escaping (Result<RentalType, Error>) -> Void
    )
    func deleteRentalType(
        id: UUID,
        pointID: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    )

    func refreshSouvenirs(pointID: UUID, completion: @escaping () -> Void)
    func getSouvenirProducts(pointID: UUID) -> [SouvenirProduct]
    func getSouvenirQuantity(productID: UUID, pointID: UUID) -> Int
    func createSouvenirProduct(
        pointID: UUID,
        name: String,
        price: Money,
        quantity: Int,
        completion: @escaping (Result<SouvenirProduct, Error>) -> Void
    )
    func updateSouvenirProduct(
        _ product: SouvenirProduct,
        quantity: Int,
        completion: @escaping (Result<SouvenirProduct, Error>) -> Void
    )
    func deleteSouvenirProduct(
        id: UUID,
        pointID: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    )

    func refreshFineTemplates(pointID: UUID, completion: @escaping () -> Void)
    func getFineTemplates(pointID: UUID) -> [FineTemplate]
    func createFineTemplate(
        pointID: UUID,
        title: String,
        amount: Money,
        completion: @escaping (Result<FineTemplate, Error>) -> Void
    )
    func updateFineTemplate(
        _ template: FineTemplate,
        completion: @escaping (Result<FineTemplate, Error>) -> Void
    )
    func deleteFineTemplate(
        id: UUID,
        pointID: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    )

    func refreshBatteryTypes(pointID: UUID, completion: @escaping () -> Void)
    func getBatteryItems(pointID: UUID) -> [BatteryItem]
    func createBatteryItem(
        pointID: UUID,
        title: String,
        quantity: Int,
        completion: @escaping (Result<BatteryItem, Error>) -> Void
    )
    func updateBatteryItem(
        _ item: BatteryItem,
        completion: @escaping (Result<BatteryItem, Error>) -> Void
    )
    func deleteBatteryItem(
        id: UUID,
        pointID: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}
