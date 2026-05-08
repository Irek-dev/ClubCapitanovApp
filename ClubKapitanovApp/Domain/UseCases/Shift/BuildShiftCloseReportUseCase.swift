import Foundation

/// Собирает неизменяемый итоговый отчет закрытия смены из snapshot-данных смены.
///
/// Use case не обращается к UI и репозиториям: ему передается уже подготовленная
/// `Shift`, а на выходе получается готовый `ShiftCloseReport` для сохранения.
struct BuildShiftCloseReportUseCase {
    private let payrollUseCase: BuildShiftPayrollSummaryUseCase

    init(payrollUseCase: BuildShiftPayrollSummaryUseCase) {
        self.payrollUseCase = payrollUseCase
    }

    func execute(
        shift: Shift,
        manualInput: ShiftCloseReportManualInput = .empty,
        createdAt: Date,
        createdByUserID: UUID? = nil
    ) -> ShiftCloseReport {
        let rentalSummary = makeRentalSummary(from: shift.rentalOrders)
        let finesSummary = makeFinesSummary(from: shift.fines)
        let souvenirSummary = makeSouvenirSummary(from: shift.souvenirSales)
        let payrollSummary = manualInput.payrollSummary ?? payrollUseCase.execute(
            shift: shift,
            closedAt: createdAt
        )

        return ShiftCloseReport(
            shiftID: shift.id,
            pointID: shift.point.id,
            shiftDate: shift.openedAt,
            createdAt: createdAt,
            createdByUserID: createdByUserID ?? shift.openedByUserID,
            weatherNote: manualInput.weatherNote,
            totalRevenue: rentalSummary.revenue + finesSummary.totalAmount + souvenirSummary.totalRevenue,
            rentalSummary: rentalSummary,
            finesSummary: finesSummary,
            souvenirSummary: souvenirSummary,
            payrollSummary: payrollSummary,
            equipmentSnapshot: manualInput.equipmentSnapshot,
            batterySnapshot: manualInput.batterySnapshot,
            notes: manualInput.notes
        )
    }

    private func makeRentalSummary(from orders: [RentalOrder]) -> ShiftRentalCloseSummary {
        let completedOrders = orders.filter { $0.status == .completed }

        return ShiftRentalCloseSummary(
            totalTripsCount: completedOrders.reduce(0) { $0 + $1.quantity },
            revenue: Money.sum(completedOrders.map(\.totalPrice)),
            tripsByType: rentalTypeRows(from: completedOrders),
            tariffBreakdown: tariffRows(from: completedOrders),
            payments: paymentRows(from: completedOrders.map { ($0.paymentMethod, $0.totalPrice) }),
            chipRevenue: nil
        )
    }

    private func makeFinesSummary(from fines: [FineRecord]) -> ShiftFinesCloseSummary {
        ShiftFinesCloseSummary(
            totalCount: fines.count,
            totalAmount: Money.sum(fines.map(\.amount)),
            rows: groupedRows(
                records: fines,
                title: \.title,
                amount: \.amount,
                makeRow: ShiftFineBreakdownRow.init
            )
        )
    }

    private func makeSouvenirSummary(from sales: [SouvenirSale]) -> ShiftSouvenirCloseSummary {
        ShiftSouvenirCloseSummary(
            totalRevenue: Money.sum(sales.map(\.totalPrice)),
            rows: groupedRows(
                records: sales,
                title: \.itemName,
                amount: \.totalPrice,
                count: \.quantity,
                makeRow: ShiftSouvenirBreakdownRow.init
            )
        )
    }

    private func rentalTypeRows(from orders: [RentalOrder]) -> [ShiftRentalTypeCountRow] {
        var countsByTitle: [String: Int] = [:]

        orders.forEach { order in
            if order.rentedItemsSnapshot.isEmpty {
                countsByTitle[order.rentalTypeNameSnapshot, default: 0] += order.quantity
                return
            }

            order.rentedItemsSnapshot.forEach { item in
                countsByTitle[item.rentalTypeNameSnapshot, default: 0] += 1
            }
        }

        return countsByTitle.keys.sorted().map { title in
            ShiftRentalTypeCountRow(title: title, count: countsByTitle[title] ?? 0)
        }
    }

    private func tariffRows(from orders: [RentalOrder]) -> [ShiftTariffBreakdownRow] {
        var amountsByTitle: [String: Money] = [:]

        orders.forEach { order in
            if !order.rentedItemsSnapshot.isEmpty {
                let itemAmounts = order.rentedItemsSnapshot.compactMap { item -> (String, Money)? in
                    guard let title = item.tariffTitleSnapshot, let price = item.tariffPriceSnapshot else {
                        return nil
                    }
                    return (title, price)
                }

                if !itemAmounts.isEmpty {
                    itemAmounts.forEach { title, amount in
                        amountsByTitle[title, default: .zero] += amount
                    }
                    return
                }
            }

            let title = "\(order.durationMinutes) мин"
            amountsByTitle[title, default: .zero] += order.totalPrice
        }

        return amountsByTitle.keys.sorted().map { title in
            ShiftTariffBreakdownRow(title: title, amount: amountsByTitle[title] ?? .zero)
        }
    }

    private func paymentRows(from rows: [(PaymentMethod, Money)]) -> [ShiftPaymentBreakdownRow] {
        var amountsByPaymentMethod: [PaymentMethod: Money] = [:]

        rows.forEach { paymentMethod, amount in
            amountsByPaymentMethod[paymentMethod, default: .zero] += amount
        }

        return PaymentMethod.allCases.compactMap { paymentMethod in
            guard let amount = amountsByPaymentMethod[paymentMethod], amount != .zero else {
                return nil
            }
            return ShiftPaymentBreakdownRow(paymentMethod: paymentMethod, amount: amount)
        }
    }

    private func groupedRows<Record, Row>(
        records: [Record],
        title: KeyPath<Record, String>,
        amount: KeyPath<Record, Money>,
        count: KeyPath<Record, Int>? = nil,
        makeRow: (String, Int, Money) -> Row
    ) -> [Row] {
        var grouped: [String: (count: Int, amount: Money)] = [:]

        records.forEach { record in
            let recordTitle = record[keyPath: title]
            let recordCount = count.map { record[keyPath: $0] } ?? 1
            var row = grouped[recordTitle] ?? (count: 0, amount: .zero)
            row.count += recordCount
            row.amount += record[keyPath: amount]
            grouped[recordTitle] = row
        }

        return grouped.keys.sorted().map { recordTitle in
            let row = grouped[recordTitle] ?? (count: 0, amount: .zero)
            return makeRow(recordTitle, row.count, row.amount)
        }
    }
}

struct ShiftCloseReportManualInput: Hashable, Codable, Sendable {
    let weatherNote: String?
    let payrollSummary: ShiftPayrollCloseSummary?
    let equipmentSnapshot: ShiftEquipmentSnapshot
    let batterySnapshot: ShiftBatterySnapshot
    let notes: String?

    init(
        weatherNote: String? = nil,
        payrollSummary: ShiftPayrollCloseSummary? = nil,
        equipmentSnapshot: ShiftEquipmentSnapshot = .empty,
        batterySnapshot: ShiftBatterySnapshot = .empty,
        notes: String? = nil
    ) {
        self.weatherNote = weatherNote
        self.payrollSummary = payrollSummary
        self.equipmentSnapshot = equipmentSnapshot
        self.batterySnapshot = batterySnapshot
        self.notes = notes
    }

    static let empty = ShiftCloseReportManualInput()
}
