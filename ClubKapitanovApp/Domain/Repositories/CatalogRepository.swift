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
    func refreshCatalog(pointID: UUID, completion: @escaping () -> Void)
}
