import Foundation

/// Статус учетной записи для входа в приложение.
///
/// Этот enum специально не описывает состояние "на смене": пользователь может быть
/// активным как учетная запись, но не находиться ни в одной открытой смене.
enum UserAccountStatus: String, Codable, Sendable, CaseIterable {
    case active
    case blocked
    case archived
}
