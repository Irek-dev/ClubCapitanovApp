import UIKit

/// Единая палитра приложения.
///
/// Все экраны берут цвета отсюда, чтобы брендовые и семантические цвета не
/// расползались по UIKit-файлам. Если нужно изменить внешний вид, сначала правится
/// этот слой, а не каждый экран отдельно.
enum BrandColor {
    // MARK: - Brandbook

    /// Основной цвет из брендбука: RGB 23/53/87, HEX #173557.
    static let brandBlue = UIColor(hex: 0x173557)

    /// Дополнительный цвет из брендбука: RGB 249/175/60, HEX #F9AF3C.
    static let brandYellow = UIColor(hex: 0xF9AF3C)

    /// Основной интерактивный синий. В темной теме используется более светлый
    /// оттенок брендового синего, чтобы кнопки и выбранные элементы не пропадали
    /// на темно-синем фоне.
    static let primaryBlue = UIColor.adaptive(light: brandBlue, dark: UIColor(hex: 0x2D5F86))

    /// Дополнительный акцент из брендбука.
    static let accentOrange = brandYellow

    // MARK: - Interface

    static let clear = UIColor.clear
    static let onPrimary = UIColor.white
    static let background = UIColor.adaptive(light: UIColor(hex: 0xF7F4EC), dark: UIColor(hex: 0x061A2A))
    static let surface = UIColor.adaptive(light: .white, dark: UIColor(hex: 0x0D2A42))
    static let surfaceMuted = UIColor.adaptive(light: UIColor(hex: 0xFCF9F1), dark: UIColor(hex: 0x123755))
    static let textPrimary = UIColor.adaptive(light: brandBlue, dark: UIColor(hex: 0xF7F4EC))
    static let textSecondary = UIColor.adaptive(
        light: brandBlue.withAlphaComponent(0.78),
        dark: UIColor(hex: 0xF7F4EC).withAlphaComponent(0.88)
    )
    static let fieldBorder = UIColor.adaptive(
        light: brandBlue.withAlphaComponent(0.18),
        dark: brandYellow.withAlphaComponent(0.28)
    )
    static let shadow = UIColor.adaptive(
        light: brandBlue.withAlphaComponent(0.16),
        dark: UIColor.black.withAlphaComponent(0.38)
    )
    static let error = UIColor.adaptive(light: UIColor(hex: 0xC13D2D), dark: UIColor(hex: 0xFF7A70))
    static let success = UIColor.adaptive(light: UIColor(hex: 0x2F9E44), dark: UIColor(hex: 0x63D471))
    static let modalOverlay = UIColor.black.withAlphaComponent(0.35)

    static func cgColor(_ color: UIColor, compatibleWith traitCollection: UITraitCollection) -> CGColor {
        color.resolvedColor(with: traitCollection).cgColor
    }
}

private extension UIColor {
    static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    }

    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}
