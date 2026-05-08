import Foundation

/// Тип проката на конкретной точке: например утки, парусники или пожарники.
///
/// Тип содержит не зашитую цену, а список тарифов из каталога точки. Сегодня этот
/// каталог приходит из in-memory репозитория; позже источник данных можно заменить
/// без изменения UI-слоя.
struct RentalType: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор типа проката.
    let id: UUID
    /// Точка, к которой относится данный тип проката.
    let pointID: UUID
    /// Человекочитаемое название типа проката.
    let name: String
    /// Короткий системный код типа.
    let code: String
    /// Доступные тарифы для этого типа на конкретной точке.
    let tariffs: [RentalTariff]
    /// Признак того, что тип активен и доступен на точке.
    let isActive: Bool

    /// Активные тарифы в порядке отображения.
    var activeTariffs: [RentalTariff] {
        tariffs
            .filter(\.isActive)
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Тариф по умолчанию для текущего UI, где интервал проката еще не выбирается вручную.
    var defaultTariff: RentalTariff? {
        activeTariffs.first
    }

    init(
        id: UUID = UUID(),
        pointID: UUID,
        name: String,
        code: String,
        tariffs: [RentalTariff],
        isActive: Bool = true
    ) {
        self.id = id
        self.pointID = pointID
        self.name = name
        self.code = code
        self.tariffs = tariffs
        self.isActive = isActive
    }
}
