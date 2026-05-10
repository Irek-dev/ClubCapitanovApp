import Foundation

struct ShiftWorkspaceContentFormatting {
    private let moneyFormatter = RubleMoneyFormatter()

    func moneyText(_ money: Money) -> String {
        moneyFormatter.string(from: money, includesCurrencySymbol: true)
    }

    func reportMoneyText(_ money: Money) -> String {
        let sign = money.kopecks < 0 ? "-" : ""
        let absoluteKopecks = abs(money.kopecks)
        let rubles = absoluteKopecks / 100
        let kopecks = absoluteKopecks % 100
        let groupedRubles = groupedThousands(rubles)

        guard kopecks > 0 else {
            return "\(sign)\(groupedRubles)₽"
        }

        return String(format: "%@%@.%02d₽", sign, groupedRubles, kopecks)
    }

    func paymentBreakdownText(_ rows: [(PaymentMethod, Money)]) -> String {
        var amountsByMethod: [PaymentMethod: Money] = [:]

        rows.forEach { method, amount in
            amountsByMethod[method, default: .zero] += amount
        }

        let parts = PaymentMethod.workspaceSelectionOrder.compactMap { method -> String? in
            guard let amount = amountsByMethod[method], amount != .zero else {
                return nil
            }
            return "\(method.workspaceShortTitle): \(reportMoneyText(amount))"
        }

        return parts.isEmpty ? "оплата не указана" : parts.joined(separator: ", ")
    }

    func formattedReportDate(_ date: Date) -> String {
        AppDateFormatter.date(date)
    }

    func formattedTime(_ date: Date) -> String {
        AppDateFormatter.time(date)
    }

    func rentalIconText(for type: RentalType) -> String {
        switch type.code {
        case "duck":
            return "🦆"
        case "sail":
            return "⛵"
        case "boat":
            return "🛥️"
        case "fireboat":
            return "🚤"
        default:
            return "🛶"
        }
    }

    func rentalIconText(for item: RentalOrderItemSnapshot, types: [RentalType]) -> String {
        if let type = types.first(where: { $0.id == item.rentalTypeID || $0.name == item.rentalTypeNameSnapshot }) {
            return rentalIconText(for: type)
        }

        switch item.rentalTypeCodeSnapshot {
        case "duck":
            return "🦆"
        case "sail":
            return "⛵"
        case "boat":
            return "🛥️"
        case "fireboat":
            return "🚤"
        default:
            return "🛶"
        }
    }

    func rentalItemsText(for order: RentalOrder, types: [RentalType]) -> String {
        rentalItems(for: order, types: types)
            .map { item in
                "\(item.rentalTypeNameSnapshot) \(item.displayNumber)"
            }
            .joined(separator: ", ")
    }

    func rentalItems(for order: RentalOrder, types: [RentalType]) -> [RentalOrderItemSnapshot] {
        if !order.rentedItemsSnapshot.isEmpty {
            return order.rentedItemsSnapshot
        }

        let fallbackType = types.first { $0.id == order.rentalTypeID || $0.name == order.rentalTypeNameSnapshot }
        return order.rentedAssetNumbersSnapshot.compactMap { numberText in
            let digits = numberText.filter(\.isNumber)
            guard let number = Int(digits) else { return nil }

            return .init(
                rentalTypeID: order.rentalTypeID,
                rentalTypeNameSnapshot: order.rentalTypeNameSnapshot,
                rentalTypeCodeSnapshot: fallbackType?.code ?? "",
                displayNumber: number
            )
        }
    }

    func tariffText(for tariff: RentalTariff?) -> String {
        guard let tariff else { return "тариф не настроен" }
        return "\(moneyText(tariff.price)) за \(tariff.title)"
    }

    func tariffText(for item: RentalOrderItemSnapshot) -> String {
        guard let title = item.tariffTitleSnapshot, let price = item.tariffPriceSnapshot else {
            return "тариф не сохранен"
        }
        return "\(moneyText(price)) за \(title)"
    }

    func reportRentalTitle(for name: String, code: String) -> String {
        switch code {
        case "duck":
            return "Уточки"
        case "sail":
            return "Парусники"
        case "fireboat":
            return "Пожарники"
        case "boat":
            return "Катера"
        default:
            return name
        }
    }

    func shortEmployeeName(_ fullName: String) -> String {
        let parts = fullName.split(separator: " ").map(String.init)
        guard parts.count > 1 else {
            return fullName
        }
        return parts[1]
    }

    private func groupedThousands(_ value: Int) -> String {
        let digits = String(value)
        var groups: [String] = []
        var endIndex = digits.endIndex

        while endIndex > digits.startIndex {
            let startIndex = digits.index(endIndex, offsetBy: -3, limitedBy: digits.startIndex) ?? digits.startIndex
            groups.append(String(digits[startIndex..<endIndex]))
            endIndex = startIndex
        }

        return groups.reversed().joined(separator: ".")
    }
}
