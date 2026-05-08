import Foundation

/// Value object для денежных значений в проекте.
///
/// Деньги хранятся в копейках (`Int`), чтобы избежать ошибок округления в расчетах.
/// `amount` оставлен как удобное представление в рублях для UI и существующего кода,
/// но бизнес-логика должна передавать деньги именно как `Money`, а не как голый `Int`.
struct Money: Hashable, Codable, Sendable {
    /// Денежная сумма в копейках.
    let kopecks: Int

    /// Денежная сумма в рублях для отображения и совместимости существующего кода.
    nonisolated var amount: Decimal {
        Decimal(kopecks) / 100
    }

    /// Валюта проекта фиксирована и всегда равна RUB.
    nonisolated var currencyCode: String {
        "RUB"
    }

    nonisolated init(kopecks: Int) {
        self.kopecks = kopecks
    }

    nonisolated init(amount: Decimal, currencyCode: String = "RUB") {
        // Валюта намеренно зафиксирована: сейчас продукт работает только в рублях,
        // поэтому любые попытки передать другую валюту считаются ошибкой разработки.
        precondition(currencyCode == "RUB", "ClubKapitanovApp currently supports only RUB.")
        self.kopecks = Self.makeKopecks(from: amount)
    }

    nonisolated static let zero = Money(amount: 0)

    nonisolated private static func makeKopecks(from rubles: Decimal) -> Int {
        // Decimal сначала масштабируется до копеек, затем округляется до целого.
        // Это сохраняет единый формат хранения даже если UI передаст дробные рубли.
        var scaled = rubles * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}
