import UIKit

/// Единая типографика приложения.
///
/// Сейчас проект использует Avenir Next, потому что файлов фирменных шрифтов из
/// брендбука в проекте нет. Когда добавим Chalet/Lena в bundle, заменить нужно
/// будет только имена шрифтов здесь.
enum BrandFont {
    static func regular(_ size: CGFloat) -> UIFont {
        font(named: "AvenirNext-Regular", size: readableSize(size), fallbackWeight: .regular)
    }

    static func medium(_ size: CGFloat) -> UIFont {
        font(named: "AvenirNext-Medium", size: readableSize(size), fallbackWeight: .medium)
    }

    static func demiBold(_ size: CGFloat) -> UIFont {
        font(named: "AvenirNext-DemiBold", size: readableSize(size), fallbackWeight: .semibold)
    }

    static func bold(_ size: CGFloat) -> UIFont {
        font(named: "AvenirNext-Bold", size: readableSize(size), fallbackWeight: .bold)
    }

    static func heavy(_ size: CGFloat) -> UIFont {
        font(named: "AvenirNext-Heavy", size: readableSize(size), fallbackWeight: .heavy)
    }

    static func timer(_ size: CGFloat) -> UIFont {
        .monospacedDigitSystemFont(ofSize: readableSize(size), weight: .bold)
    }

    private static func font(named name: String, size: CGFloat, fallbackWeight: UIFont.Weight) -> UIFont {
        UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallbackWeight)
    }

    private static func readableSize(_ size: CGFloat) -> CGFloat {
        switch size {
        case ..<14:
            return 15
        case ..<18:
            return size + 2
        case ..<24:
            return size + 2
        case ..<30:
            return size + 3
        default:
            return size + 2
        }
    }
}
