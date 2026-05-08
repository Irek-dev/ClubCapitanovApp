import Foundation

/// Участник смены: не учетная запись, а факт допуска пользователя к конкретной смене.
///
/// Это место, где живет смысл "сотрудник на смене". Snapshot имени и роли нужен,
/// чтобы исторические отчеты не менялись, если пользователя позже переименуют,
/// заблокируют или архивируют.
struct ShiftParticipant: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор записи участия в смене.
    let id: UUID
    /// Смена, в которую добавлен сотрудник.
    let shiftID: UUID
    /// Учетная запись пользователя, добавленного в смену.
    let userID: UUID
    /// Имя пользователя в том виде, в котором оно должно остаться в истории.
    let displayNameSnapshot: String
    /// Роль пользователя на момент добавления в смену.
    let roleSnapshot: UserRole
    /// Время, когда сотрудник был добавлен в смену.
    let joinedAt: Date
    /// Время, когда сотрудник покинул смену, если это произошло.
    let leftAt: Date?
    /// Дополнительная историческая заметка по участию в смене.
    let notes: String?

    init(
        id: UUID = UUID(),
        shiftID: UUID,
        userID: UUID,
        displayNameSnapshot: String,
        roleSnapshot: UserRole,
        joinedAt: Date,
        leftAt: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.shiftID = shiftID
        self.userID = userID
        self.displayNameSnapshot = displayNameSnapshot
        self.roleSnapshot = roleSnapshot
        self.joinedAt = joinedAt
        self.leftAt = leftAt
        self.notes = notes
    }

    func leaving(at leftAt: Date) -> ShiftParticipant {
        ShiftParticipant(
            id: id,
            shiftID: shiftID,
            userID: userID,
            displayNameSnapshot: displayNameSnapshot,
            roleSnapshot: roleSnapshot,
            joinedAt: joinedAt,
            leftAt: leftAt,
            notes: notes
        )
    }
}
