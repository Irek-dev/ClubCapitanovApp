import Foundation

/// Физическое устройство, через которое пользователь подключается к смене.
///
/// Главный сценарий сейчас — общий iPad точки. Он считается host-устройством смены
/// и привязывает рабочую сессию к конкретной точке.
struct WorkDevice: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор устройства в системе.
    let id: UUID
    /// Человекочитаемое имя устройства для UI и исторических записей.
    let name: String
    /// Тип устройства, подключенного к рабочему контексту смены.
    let kind: DeviceKind
    /// Идентификатор точки, к которой закреплено устройство, если оно стационарное.
    let assignedPointID: UUID?
    /// Признак общего устройства точки, через которое обычно открывают смену.
    let isSharedPointDevice: Bool
    /// Признак того, что устройство активно и может подключаться к сменам.
    let isActive: Bool

    init(
        id: UUID = UUID(),
        name: String,
        kind: DeviceKind,
        assignedPointID: UUID? = nil,
        isSharedPointDevice: Bool = false,
        isActive: Bool = true
    ) {
        // Все поля намеренно immutable: старые смены должны сохранять версию данных
        // устройства, актуальную на момент открытия смены.
        self.id = id
        self.name = name
        self.kind = kind
        self.assignedPointID = assignedPointID
        self.isSharedPointDevice = isSharedPointDevice
        self.isActive = isActive
    }
}
