import Foundation

/// UI-представление способов оплаты внутри workspace.
///
/// Доменный `PaymentMethod` хранит только стабильные значения, а порядок и русские
/// подписи остаются в feature-слое, где они реально нужны интерфейсу и отчетам.
extension PaymentMethod {
    var workspaceTitle: String {
        switch self {
        case .cash:
            return "Наличные"
        case .card:
            return "Карта"
        case .qr:
            return "Перевод / QR"
        }
    }

    var workspaceShortTitle: String {
        switch self {
        case .cash:
            return "Нал"
        case .card:
            return "Карта"
        case .qr:
            return "Перевод"
        }
    }

    static let workspaceSelectionOrder: [PaymentMethod] = [.card, .cash, .qr]
}
