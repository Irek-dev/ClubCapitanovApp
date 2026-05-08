import Foundation

/// Техническое подключение пользователя и устройства к смене.
///
/// Эта сущность отделена от `ShiftParticipant`: участник означает допуск к работе
/// в смене, а connection описывает конкретное устройство и режим подключения.
struct ShiftConnection: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор подключения к смене.
    let id: UUID
    /// Смена, к которой относится подключение.
    let shiftID: UUID
    /// Пользователь, который подключился к смене с устройства.
    let userID: UUID
    /// Устройство, с которого пользователь работает в смене.
    let deviceID: UUID
    /// Время подключения пользователя к смене.
    let connectedAt: Date
    /// Время отключения пользователя от смены, если работа уже завершена.
    let disconnectedAt: Date?
    /// Режим подключения устройства к смене.
    let mode: ShiftConnectionMode

    init(
        id: UUID = UUID(),
        shiftID: UUID,
        userID: UUID,
        deviceID: UUID,
        connectedAt: Date,
        disconnectedAt: Date? = nil,
        mode: ShiftConnectionMode
    ) {
        self.id = id
        self.shiftID = shiftID
        self.userID = userID
        self.deviceID = deviceID
        self.connectedAt = connectedAt
        self.disconnectedAt = disconnectedAt
        self.mode = mode
    }
}
