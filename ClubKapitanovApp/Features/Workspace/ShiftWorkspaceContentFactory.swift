import Foundation

/// Собирает display-модели центральной области Workspace.
///
/// Presenter остается тонкой точкой входа, а вся детализация секций, отчетных строк,
/// форматирования и fallback-логики исторических заказов живет здесь.
final class ShiftWorkspaceContentFactory {
    private struct RentalReportBreakdownRow {
        let typeID: UUID?
        let typeName: String
        let title: String
        var count: Int
        var amount: Money
    }

    private struct PaymentReportTotals {
        var cash: Money = .zero
        var card: Money = .zero
        var transfer: Money = .zero
    }

    private struct OperationReportRemainder {
        var count: Int
        var total: Money
    }

    private let formatting = ShiftWorkspaceContentFormatting()
    private let payrollUseCase: BuildShiftPayrollSummaryUseCase
    private let dateProvider: DateProviding

    init(
        payrollUseCase: BuildShiftPayrollSummaryUseCase,
        dateProvider: DateProviding
    ) {
        self.payrollUseCase = payrollUseCase
        self.dateProvider = dateProvider
    }

    func makeContentViewModel(from state: ShiftWorkspace.State) -> ShiftWorkspace.ContentViewModel {
        switch state.selectedSection {
        case .ducks:
            return .ducks(
                intro: "Прокат уток и управление заказами",
                createOrderButtonTitle: "Новый заказ",
                rentalTypes: rentalOrderItemTypes(from: state),
                activeOrders: activeRentalOrderViewModels(from: state),
                summaryLines: [],
                report: .init(
                    title: "Объекты в плавании",
                    emptyText: "Сейчас ничего не плавает",
                    rows: rentalReportRows(from: state)
                )
            )
        case .souvenirs:
            return .souvenirs(
                intro: "Продажа сувенирной продукции",
                buttons: state.souvenirProducts.enumerated().map { index, product in
                    .init(
                        index: index,
                        title: "\(product.name) — \(formatting.moneyText(product.price))",
                        itemTitle: product.name,
                        unitPrice: product.price,
                        confirmationTitle: "Подтвердите покупку",
                        confirmButtonTitle: "Добавить"
                    )
                },
                summaryLines: [],
                report: .init(
                    title: "Список сувенирки",
                    emptyText: "Сувенирка пока не продавалась",
                    rows: souvenirReportRows(from: state),
                    footerText: "Итого: \(formatting.moneyText(Money.sum(state.souvenirSales.map(\.totalPrice))))"
                )
            )
        case .fines:
            return .fines(
                intro: "Штрафы за поломку и повреждение оборудования",
                buttons: state.fineTemplates.enumerated().map { index, template in
                    .init(
                        index: index,
                        title: "\(template.title) — \(formatting.moneyText(template.amount))",
                        itemTitle: template.title,
                        unitPrice: template.amount,
                        confirmationTitle: "Подтвердите штраф",
                        confirmButtonTitle: "Добавить"
                    )
                },
                summaryLines: [],
                report: .init(
                    title: "Список штрафов",
                    emptyText: "Штрафов пока нет",
                    rows: fineReportRows(from: state),
                    footerText: "Итого: \(formatting.moneyText(Money.sum(state.fines.map(\.amount))))"
                )
            )
        case .temporaryReport:
            return .temporaryReport(
                intro: "Временный отчет смены",
                infoLines: temporaryOverviewLines(in: state),
                rentalLines: [],
                summaryLines: [],
                employeeLines: [],
                souvenirReport: .init(
                    title: "Сувенирка",
                    emptyText: "Продаж сувенирки пока нет",
                    rows: temporarySouvenirRows(in: state),
                    footerText: "Итого: \(formatting.reportMoneyText(Money.sum(state.souvenirSales.map(\.totalPrice))))"
                ),
                fineReport: .init(
                    title: "Штрафы",
                    emptyText: "Штрафов пока нет",
                    rows: temporaryFineRows(in: state),
                    footerText: "Итого: \(formatting.reportMoneyText(Money.sum(state.fines.map(\.amount))))"
                )
            )
        case .closeShift:
            return .closeShift(
                intro: "Итоговый отчет перед закрытием",
                shiftLines: finalReportLines(in: state),
                buttonTitle: "Закрыть смену"
            )
        }
    }

    func makeCloseShiftModalViewModel(from state: ShiftWorkspace.State) -> ShiftWorkspace.CloseShiftModalViewModel {
        return .init(
            totalsLines: finalReportLines(in: state),
            reportDateText: "Дата отчета: \(formatting.formattedReportDate(state.shift.openedAt))",
            weatherTitle: "Погода",
            weatherPlaceholder: "Например: ясно, +20",
            equipmentRows: closeEquipmentRows(in: state),
            batteryRows: closeBatteryRows(),
            dismissButtonTitle: "Отмена",
            confirmButtonTitle: "Закрыть смену"
        )
    }

    private func rentalOrderItemTypes(from state: ShiftWorkspace.State) -> [ShiftWorkspace.RentalOrderItemTypeViewModel] {
        state.rentalTypes.enumerated().map { index, type in
            .init(
                index: index,
                title: type.name,
                tariffText: formatting.tariffText(for: type.defaultTariff),
                iconText: formatting.rentalIconText(for: type),
                floatingNumbers: floatingNumbers(for: type, in: state)
            )
        }
    }

    private func activeRentalOrderViewModels(from state: ShiftWorkspace.State) -> [ShiftWorkspace.ActiveRentalOrderViewModel] {
        activeRentalOrders(in: state)
            .sorted { $0.startedAt < $1.startedAt }
            .enumerated()
            .map { index, order in
                .init(
                    id: order.id,
                    title: "Заказ #\(index + 1)",
                    itemsText: formatting.rentalItemsText(for: order, types: state.rentalTypes),
                    startedAtText: "Старт: \(formatting.formattedTime(order.startedAt))",
                    totalAmountText: "К оплате: \(formatting.moneyText(order.totalPrice))",
                    startedAt: order.startedAt,
                    expectedEndAt: order.expectedEndAt,
                    completeButtonTitle: "Завершить"
                )
            }
    }

    private func rentalReportRows(from state: ShiftWorkspace.State) -> [ShiftWorkspace.ReportRowViewModel] {
        state.rentalTypes.compactMap { type in
            let items = activeRentalItems(in: state).filter { item in
                item.rentalTypeID == type.id || item.rentalTypeNameSnapshot == type.name
            }
            let quantity = items.count
            guard quantity > 0 else { return nil }

            let numbers = items
                .map(\.displayNumber)
                .sorted()
                .map { "№\($0)" }
                .joined(separator: ", ")
            return .init(
                title: "\(formatting.rentalIconText(for: type)) \(type.name)",
                detail: numbers,
                amount: "\(quantity) шт.",
                quantityAdjustment: nil
            )
        }
    }

    private func souvenirReportRows(from state: ShiftWorkspace.State) -> [ShiftWorkspace.ReportRowViewModel] {
        var handledSaleIDs = Set<UUID>()
        var rows: [ShiftWorkspace.ReportRowViewModel] = []

        state.souvenirProducts.enumerated().forEach { index, product in
            let matchingSales = state.souvenirSales.filter { sale in
                sale.productID == product.id || sale.itemName == product.name
            }
            let count = matchingSales.reduce(0) { $0 + $1.quantity }
            guard count > 0 else { return }

            matchingSales.forEach { handledSaleIDs.insert($0.id) }
            let total = Money.sum(matchingSales.map(\.totalPrice))
            rows.append(
                .init(
                    title: product.name,
                    detail: "\(count) шт. · \(formatting.paymentBreakdownText(matchingSales.map { ($0.paymentMethod, $0.totalPrice) }))",
                    amount: formatting.moneyText(total),
                    quantityAdjustment: .init(kind: .souvenir, index: index)
                )
            )
        }

        var remainingRows: [String: OperationReportRemainder] = [:]
        state.souvenirSales
            .filter { !handledSaleIDs.contains($0.id) }
            .forEach { sale in
                var row = remainingRows[sale.itemName] ?? OperationReportRemainder(count: 0, total: .zero)
                row.count += sale.quantity
                row.total += sale.totalPrice
                remainingRows[sale.itemName] = row
            }

        rows.append(contentsOf: remainingReportRows(from: remainingRows))

        return rows
    }

    private func fineReportRows(from state: ShiftWorkspace.State) -> [ShiftWorkspace.ReportRowViewModel] {
        var handledFineIDs = Set<UUID>()
        var rows: [ShiftWorkspace.ReportRowViewModel] = []

        state.fineTemplates.enumerated().forEach { index, template in
            let matchingFines = state.fines.filter { fine in
                fine.templateID == template.id || fine.title == template.title
            }
            guard !matchingFines.isEmpty else { return }

            matchingFines.forEach { handledFineIDs.insert($0.id) }
            let total = Money.sum(matchingFines.map(\.amount))
            rows.append(
                .init(
                    title: template.title,
                    detail: "\(matchingFines.count) шт. · \(formatting.paymentBreakdownText(matchingFines.map { ($0.paymentMethod, $0.amount) }))",
                    amount: formatting.moneyText(total),
                    quantityAdjustment: .init(kind: .fine, index: index)
                )
            )
        }

        var remainingRows: [String: OperationReportRemainder] = [:]
        state.fines
            .filter { !handledFineIDs.contains($0.id) }
            .forEach { fine in
                var row = remainingRows[fine.title] ?? OperationReportRemainder(count: 0, total: .zero)
                row.count += 1
                row.total += fine.amount
                remainingRows[fine.title] = row
            }

        rows.append(contentsOf: remainingReportRows(from: remainingRows))

        return rows
    }

    private func remainingReportRows(
        from remainingRows: [String: OperationReportRemainder]
    ) -> [ShiftWorkspace.ReportRowViewModel] {
        remainingRows.keys.sorted().compactMap { title in
            guard let row = remainingRows[title] else { return nil }
            return .init(
                title: title,
                detail: "\(row.count) шт.",
                amount: formatting.moneyText(row.total),
                quantityAdjustment: nil
            )
        }
    }

    private func activeRentalOrders(in state: ShiftWorkspace.State) -> [RentalOrder] {
        state.rentalOrders.filter { $0.status == .active }
    }

    private func completedRentalOrders(in state: ShiftWorkspace.State) -> [RentalOrder] {
        state.rentalOrders.filter { $0.status == .completed }
    }

    private func activeRentalItems(in state: ShiftWorkspace.State) -> [RentalOrderItemSnapshot] {
        activeRentalOrders(in: state).flatMap { formatting.rentalItems(for: $0, types: state.rentalTypes) }
    }

    private func floatingNumbers(for type: RentalType, in state: ShiftWorkspace.State) -> [Int] {
        activeRentalItems(in: state)
            .filter { $0.rentalTypeID == type.id || $0.rentalTypeNameSnapshot == type.name }
            .map(\.displayNumber)
            .sorted()
    }

    private func completedRentalQuantity(in state: ShiftWorkspace.State) -> Int {
        completedRentalOrders(in: state).reduce(0) { $0 + $1.quantity }
    }

    private func closeEquipmentRows(in state: ShiftWorkspace.State) -> [ShiftWorkspace.CloseShiftManualRowViewModel] {
        state.rentalTypes.map { type in
            .init(
                title: formatting.reportRentalTitle(for: type.name, code: type.code),
                placeholder: "0"
            )
        }
    }

    private func closeBatteryRows() -> [ShiftWorkspace.CloseShiftManualRowViewModel] {
        [
            "Kweller",
            "Ladda",
            "LiitoKala серые",
            "LiitoKala желтые",
            "Chameleon",
            "Rexant",
            "Космос"
        ].map { title in
            .init(title: title, placeholder: "0")
        }
    }

    private func temporaryOverviewLines(in state: ShiftWorkspace.State) -> [String] {
        let rentalTotal = Money.sum(completedRentalOrders(in: state).map(\.totalPrice))
        let souvenirTotal = Money.sum(state.souvenirSales.map(\.totalPrice))
        let finesTotal = Money.sum(state.fines.map(\.amount))
        let total = rentalTotal + souvenirTotal + finesTotal

        return [
            "Дата: \(formatting.formattedReportDate(state.shift.openedAt))",
            "Открыта: \(formatting.formattedTime(state.shift.openedAt))",
            "Длительность: \(shiftDurationText(from: state.shift))",
            "Общая выручка: \(formatting.reportMoneyText(total))"
        ]
    }

    private func temporarySouvenirRows(in state: ShiftWorkspace.State) -> [ShiftWorkspace.ReportRowViewModel] {
        state.souvenirSales
            .sorted { $0.soldAt < $1.soldAt }
            .map { sale in
                .init(
                    title: sale.itemName,
                    detail: "\(formatting.formattedTime(sale.soldAt)) · \(sale.quantity) шт. · \(sale.paymentMethod.workspaceTitle)",
                    amount: formatting.reportMoneyText(sale.totalPrice),
                    quantityAdjustment: nil
                )
            }
    }

    private func temporaryFineRows(in state: ShiftWorkspace.State) -> [ShiftWorkspace.ReportRowViewModel] {
        state.fines
            .sorted { $0.createdAt < $1.createdAt }
            .map { fine in
                .init(
                    title: fine.title,
                    detail: "\(formatting.formattedTime(fine.createdAt)) · 1 шт. · \(fine.paymentMethod.workspaceTitle)",
                    amount: formatting.reportMoneyText(fine.amount),
                    quantityAdjustment: nil
                )
            }
    }

    private func rentalReportBreakdownRows(in state: ShiftWorkspace.State) -> [RentalReportBreakdownRow] {
        var rows = state.rentalTypes.map { type in
            RentalReportBreakdownRow(
                typeID: type.id,
                typeName: type.name,
                title: formatting.reportRentalTitle(for: type.name, code: type.code),
                count: 0,
                amount: .zero
            )
        }

        completedRentalOrders(in: state).forEach { order in
            let items = formatting.rentalItems(for: order, types: state.rentalTypes)

            if items.isEmpty {
                addRentalReport(
                    typeID: order.rentalTypeID,
                    typeName: order.rentalTypeNameSnapshot,
                    code: state.rentalTypes.first { $0.id == order.rentalTypeID }?.code ?? "",
                    count: order.quantity,
                    amount: order.totalPrice,
                    rows: &rows
                )
                return
            }

            let fallbackAmounts = split(amount: order.totalPrice, into: items.count)
            items.enumerated().forEach { index, item in
                let amount = item.tariffPriceSnapshot ?? fallbackAmounts[index]
                addRentalReport(
                    typeID: item.rentalTypeID,
                    typeName: item.rentalTypeNameSnapshot,
                    code: item.rentalTypeCodeSnapshot,
                    count: 1,
                    amount: amount,
                    rows: &rows
                )
            }
        }

        return rows
    }

    private func addRentalReport(
        typeID: UUID?,
        typeName: String,
        code: String,
        count: Int,
        amount: Money,
        rows: inout [RentalReportBreakdownRow]
    ) {
        if let rowIndex = rows.firstIndex(where: { row in
            row.typeID == typeID || row.typeName == typeName
        }) {
            rows[rowIndex].count += count
            rows[rowIndex].amount += amount
            return
        }

        rows.append(
            RentalReportBreakdownRow(
                typeID: typeID,
                typeName: typeName,
                title: formatting.reportRentalTitle(for: typeName, code: code),
                count: count,
                amount: amount
            )
        )
    }

    private func split(amount: Money, into parts: Int) -> [Money] {
        guard parts > 0 else { return [] }

        let base = amount.kopecks / parts
        let remainder = amount.kopecks % parts
        return (0..<parts).map { index in
            Money(kopecks: base + (index < remainder ? 1 : 0))
        }
    }

    private func finalReportLines(in state: ShiftWorkspace.State) -> [String] {
        let rentalRows = rentalReportBreakdownRows(in: state)
        let rentalTotal = Money.sum(completedRentalOrders(in: state).map(\.totalPrice))
        let souvenirTotal = Money.sum(state.souvenirSales.map(\.totalPrice))
        let finesTotal = Money.sum(state.fines.map(\.amount))
        let total = rentalTotal + souvenirTotal + finesTotal
        let payments = paymentTotals(in: state)

        var lines = [
            "#Итоговый отчет",
            "Дата: \(formatting.formattedReportDate(state.shift.openedAt))",
            "Точка: \(state.shift.point.name)",
            "Открыта: \(formatting.formattedTime(state.shift.openedAt))",
            "Погода: не заполнено",
            "Общая выручка: \(formatting.reportMoneyText(total))",
            "",
            "Прокат",
            "Сдано объектов: \(completedRentalQuantity(in: state))",
            "Выручка по сдачам: \(formatting.reportMoneyText(rentalTotal))"
        ]
        lines += rentalRows.map { row in
            "\(row.title): \(row.count) - \(formatting.reportMoneyText(row.amount))"
        }
        lines += [
            "",
            "Оплата",
            "Наличка: \(formatting.reportMoneyText(payments.cash))",
            "Карта: \(formatting.reportMoneyText(payments.card))",
            "Перевод: \(formatting.reportMoneyText(payments.transfer))",
            "Пришло по фишкам: 0",
            "",
            "Сувенирка"
        ]
        lines += souvenirFinalReportLines(in: state)
        lines += [
            "",
            "Штрафы"
        ]
        lines += fineFinalReportLines(in: state)
        lines += [
            "",
        ]
        lines += payrollLines(in: state)
        lines += [
            ""
        ]
        return lines
    }

    private func payrollLines(in state: ShiftWorkspace.State) -> [String] {
        guard let payrollSummary = payrollSummary(in: state) else {
            return [
                "ЗП общее: \(formatting.reportMoneyText(.zero))"
            ]
        }

        let employeeLines = payrollSummary.rows.map { row in
            "\(formatting.shortEmployeeName(row.employeeName)): \(formatting.reportMoneyText(row.amount))"
        }

        return [
            "ЗП общее: \(formatting.reportMoneyText(payrollSummary.totalAmount))"
        ] + employeeLines
    }

    private func payrollSummary(in state: ShiftWorkspace.State) -> ShiftPayrollCloseSummary? {
        let shift = state.shift.replacingOperations(
            rentalOrders: state.rentalOrders,
            souvenirSales: state.souvenirSales,
            fines: state.fines
        )
        return payrollUseCase.execute(shift: shift, closedAt: dateProvider.now)
    }

    private func paymentTotals(in state: ShiftWorkspace.State) -> PaymentReportTotals {
        var totals = PaymentReportTotals()
        let paymentRows = completedRentalOrders(in: state).map { ($0.paymentMethod, $0.totalPrice) }
            + state.souvenirSales.map { ($0.paymentMethod, $0.totalPrice) }
            + state.fines.map { ($0.paymentMethod, $0.amount) }

        paymentRows.forEach { paymentMethod, amount in
            switch paymentMethod {
            case .cash:
                totals.cash += amount
            case .card:
                totals.card += amount
            case .qr:
                totals.transfer += amount
            }
        }

        return totals
    }

    private func souvenirFinalReportLines(in state: ShiftWorkspace.State) -> [String] {
        finalOperationReportLines(
            records: state.souvenirSales,
            title: \.itemName,
            amount: \.totalPrice,
            count: \.quantity,
            emptyText: "Продаж сувенирки нет"
        )
    }

    private func fineFinalReportLines(in state: ShiftWorkspace.State) -> [String] {
        finalOperationReportLines(
            records: state.fines,
            title: \.title,
            amount: \.amount,
            emptyText: "Штрафов нет"
        )
    }

    private func finalOperationReportLines<Record>(
        records: [Record],
        title: KeyPath<Record, String>,
        amount: KeyPath<Record, Money>,
        count: KeyPath<Record, Int>? = nil,
        emptyText: String
    ) -> [String] {
        let rows = groupedOperationRows(
            records: records,
            title: title,
            amount: amount,
            count: count
        )
        let total = Money.sum(records.map { $0[keyPath: amount] })

        guard !rows.isEmpty else {
            return [
                emptyText,
                "Итого: \(formatting.reportMoneyText(total))"
            ]
        }

        return rows.map { row in
            "- \(row.title) — \(row.count) — \(formatting.reportMoneyText(row.amount))"
        } + [
            "Итого: \(formatting.reportMoneyText(total))"
        ]
    }

    private func groupedOperationRows<Record>(
        records: [Record],
        title: KeyPath<Record, String>,
        amount: KeyPath<Record, Money>,
        count: KeyPath<Record, Int>? = nil
    ) -> [(title: String, count: Int, amount: Money)] {
        var grouped: [String: (count: Int, amount: Money)] = [:]

        records.forEach { record in
            let recordTitle = record[keyPath: title]
            let recordCount = count.map { record[keyPath: $0] } ?? 1
            var row = grouped[recordTitle] ?? (count: 0, amount: .zero)
            row.count += recordCount
            row.amount += record[keyPath: amount]
            grouped[recordTitle] = row
        }

        return grouped.keys.sorted().map { title in
            let row = grouped[title] ?? (count: 0, amount: .zero)
            return (title: title, count: row.count, amount: row.amount)
        }
    }

    private func shiftDurationText(from shift: Shift) -> String {
        let minutes = max(0, Int(dateProvider.now.timeIntervalSince(shift.openedAt) / 60))
        return "\(minutes / 60) ч \(minutes % 60) мин"
    }
}
