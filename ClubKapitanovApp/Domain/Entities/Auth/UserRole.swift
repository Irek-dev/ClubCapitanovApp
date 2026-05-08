import Foundation

/// Роль пользователя в системе.
///
/// Роль влияет на доступный сценарий после PIN-входа: staff/manager проходят в
/// рабочий iPad-flow, admin должен обрабатываться отдельной админкой и не смешиваться
/// с операционным приложением смены.
enum UserRole: String, Codable, Sendable, CaseIterable {
    case staff
    case manager
    case admin
}
