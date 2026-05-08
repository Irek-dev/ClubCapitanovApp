import Foundation

/// Учетная запись пользователя для PIN-входа и проверки прав доступа.
///
/// `User` намеренно не хранит "на смене / не на смене": это временное состояние
/// относится к `ShiftParticipant`. Здесь остаются только данные аккаунта и область
/// доступа, например закрепленная точка у управляющего.
struct User: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор пользователя в системе.
    let id: UUID
    /// PIN-код, по которому пользователь входит в приложение.
    let pinCode: String
    /// Имя сотрудника
    let firstName: String
    /// Фамилия сотрудника
    let lastName: String
    /// Роль пользователя, определяющая доступные сценарии и права.
    let role: UserRole
    /// Статус учетной записи, влияющий на возможность входа.
    let accountStatus: UserAccountStatus
    /// Точка, которой управляет пользователь, если он выступает как manager.
    let managedPointID: UUID?

    init(
        id: UUID = UUID(),
        pinCode: String,
        firstName: String,
        lastName: String,
        role: UserRole,
        accountStatus: UserAccountStatus = .active,
        managedPointID: UUID? = nil
    ) {
        self.id = id
        self.pinCode = pinCode
        self.firstName = firstName
        self.lastName = lastName
        self.role = role
        self.accountStatus = accountStatus
        self.managedPointID = managedPointID
    }

    var fullName: String {
        // Единый формат имени, который затем копируется в snapshot участника смены.
        "\(lastName) \(firstName)"
    }

    var canSignIn: Bool {
        // Пока правило входа простое: только active-аккаунты могут пользоваться app.
        accountStatus == .active
    }
}
