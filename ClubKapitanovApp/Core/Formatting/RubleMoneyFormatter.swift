import Foundation

struct RubleMoneyFormatter {
    func string(from money: Money, includesCurrencySymbol: Bool = false) -> String {
        let value = amountString(from: money)
        return includesCurrencySymbol ? "\(value) ₽" : value
    }

    func string(from amount: Decimal, includesCurrencySymbol: Bool = false) -> String {
        string(from: Money(amount: amount), includesCurrencySymbol: includesCurrencySymbol)
    }

    private func amountString(from money: Money) -> String {
        let sign = money.kopecks < 0 ? "-" : ""
        let absoluteKopecks = abs(money.kopecks)
        let rubles = absoluteKopecks / 100
        let kopecks = absoluteKopecks % 100

        guard kopecks > 0 else {
            return "\(sign)\(rubles)"
        }

        return String(format: "%@%d.%02d", sign, rubles, kopecks)
    }
}
