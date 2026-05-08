import Foundation

/// Абстракция каталогов точки: типы проката, тарифы, единицы проката, сувенирка и штрафы.
///
/// UI получает каталоги через протокол, поэтому кнопки в workspace не хардкодят
/// ассортимент и цены. При подключении постоянного storage или backend достаточно
/// заменить реализацию репозитория и mapper'ы в `Data`.
protocol CatalogRepository {
    func getRentalTypes(pointID: UUID) -> [RentalType]
    func getRentalAssets(pointID: UUID) -> [RentalAsset]
    func getSouvenirProducts(pointID: UUID) -> [SouvenirProduct]
    func getFineTemplates(pointID: UUID) -> [FineTemplate]
}
