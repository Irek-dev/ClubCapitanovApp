import Foundation

/// Рабочая точка проката, на которой открывается смена.
///
/// Точка является корневым контекстом для каталогов, смен, отчетов и доступа
/// управляющего. `isActive` позволяет скрывать закрытые точки, не теряя историю.
struct Point: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор рабочей точки.
    let id: UUID
    /// Название точки для выбора и отображения в отчетах.
    let name: String
    /// Город, в котором находится точка.
    let city: String
    /// Физический адрес точки.
    let address: String
    /// Признак того, что точка активна и доступна для работы.
    let isActive: Bool

    init(
        id: UUID = UUID(),
        name: String,
        city: String,
        address: String,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.address = address
        self.isActive = isActive
    }
}
