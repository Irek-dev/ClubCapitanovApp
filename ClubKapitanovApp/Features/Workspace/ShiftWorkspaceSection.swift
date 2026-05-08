import UIKit

/// Разделы основного рабочего экрана смены.
///
/// Один enum управляет и порядком пунктов в сайдбаре, и заголовками, и SF Symbols,
/// и цветами акцентов. Так Presenter/View не держат параллельные массивы настроек.
enum ShiftWorkspaceSection: Int, CaseIterable {
    case ducks
    case souvenirs
    case fines
    case temporaryReport
    case closeShift

    var title: String {
        switch self {
        case .ducks:
            return "Утки"
        case .souvenirs:
            return "Сувенирка"
        case .fines:
            return "Штрафы"
        case .temporaryReport:
            return "Временный отчет"
        case .closeShift:
            return "Закрытие смены"
        }
    }

    var iconName: String {
        switch self {
        case .ducks:
            return "sailboat.fill"
        case .souvenirs:
            return "gift.fill"
        case .fines:
            return "exclamationmark.triangle.fill"
        case .temporaryReport:
            return "chart.bar.fill"
        case .closeShift:
            return "checkmark.seal.fill"
        }
    }

    var tintColor: UIColor {
        switch self {
        case .ducks:
            return BrandColor.primaryBlue
        case .souvenirs:
            return BrandColor.accentOrange
        case .fines:
            return BrandColor.error
        case .temporaryReport:
            return BrandColor.primaryBlue
        case .closeShift:
            return BrandColor.error
        }
    }
}
