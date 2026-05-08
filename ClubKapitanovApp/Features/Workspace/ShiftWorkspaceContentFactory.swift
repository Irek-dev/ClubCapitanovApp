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

    private let moneyFormatter = RubleMoneyFormatter()
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
                        title: "\(product.name) — \(moneyText(product.price))",
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
                    footerText: "Итого: \(moneyText(Money.sum(state.souvenirSales.map(\.totalPrice))))"
                )
            )
        case .fines:
            return .fines(
                intro: "Штрафы за поломку и повреждение оборудования",
                buttons: state.fineTemplates.enumerated().map { index, template in
                    .init(
                        index: index,
                        title: "\(template.title) — \(moneyText(template.amount))",
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
                    footerText: "Итого: \(moneyText(Money.sum(state.fines.map(\.amount))))"
                )
            )
        case .temporaryReport:
            return .temporaryReport(
                intro: "Временный отчет смены",
                infoLines: temporaryOverviewLines(in: state),
                rentalLines: temporaryRentalLines(in: state),
                summaryLines: temporaryPaymentLines(in: state),
                employeeLines: temporaryEmployeeLines(in: state),
                souvenirReport: .init(
                    title: "Сувенирка по операциям",
                    emptyText: "Продаж сувенирки пока нет",
                    rows: temporarySouvenirRows(in: state),
                    footerText: "Итого: \(reportMoneyText(Money.sum(state.souvenirSales.map(\.totalPrice))))"
                ),
                fineReport: .init(
                    title: "Штрафы по операциям",
                    emptyText: "Штрафов пока нет",
                    rows: temporaryFineRows(in: state),
                    footerText: "Итого: \(reportMoneyText(Money.sum(state.fines.map(\.amount))))"
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
            reportDateText: "Дата отчета: \(formattedReportDate(state.shift.openedAt))",
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
                tariffText: tariffText(for: type.defaultTariff),
                iconText: rentalIconText(for: type),
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
                    itemsText: rentalItemsText(for: order, types: state.rentalTypes),
                    startedAtText: "Старт: \(formattedTime(order.startedAt))",
                    totalAmountText: "К оплате: \(moneyText(order.totalPrice))",
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
                title: "\(rentalIconText(for: type)) \(type.name)",
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
                    detail: "\(count) шт. · \(paymentBreakdownText(matchingSales.map { ($0.paymentMethod, $0.totalPrice) }))",
                    amount: moneyText(total),
                    quantityAdjustment: .init(kind: .souvenir, index: index)
                )
            )
        }

        var remainingRows: [String: (count: Int, total: Money)] = [:]
        state.souvenirSales
            .filter { !handledSaleIDs.contains($0.id) }
            .forEach { sale in
                var row = remainingRows[sale.itemName] ?? (count: 0, total: .zero)
                row.count += sale.quantity
                row.total += sale.totalPrice
                remainingRows[sale.itemName] = row
            }

        rows.append(
            contentsOf: remainingRows.keys.sorted().compactMap { title in
                guard let row = remainingRows[title] else { return nil }
                return .init(
                    title: title,
                    detail: "\(row.count) шт.",
                    amount: moneyText(row.total),
                    quantityAdjustment: nil
                )
            }
        )

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
                    detail: "\(matchingFines.count) шт. · \(paymentBreakdownText(matchingFines.map { ($0.paymentMethod, $0.amount) }))",
                    amount: moneyText(total),
                    quantityAdjustment: .init(kind: .fine, index: index)
                )
            )
        }

        var remainingRows: [String: (count: Int, total: Money)] = [:]
        state.fines
            .filter { !handledFineIDs.contains($0.id) }
            .forEach { fine in
                var row = remainingRows[fine.title] ?? (count: 0, total: .zero)
                row.count += 1
                row.total += fine.amount
                remainingRows[fine.title] = row
            }

        rows.append(
            contentsOf: remainingRows.keys.sorted().compactMap { title in
                guard let row = remainingRows[title] else { return nil }
                return .init(
                    title: title,
                    detail: "\(row.count) шт.",
                    amount: moneyText(row.total),
                    quantityAdjustment: nil
                )
            }
        )

        return rows
    }

    private func activeRentalOrders(in state: ShiftWorkspace.State) -> [RentalOrder] {
        state.rentalOrders.filter { $0.status == .active }
    }

    private func completedRentalOrders(in state: ShiftWorkspace.State) -> [RentalOrder] {
        state.rentalOrders.filter { $0.status == .completed }
    }

    private func activeRentalItems(in state: ShiftWorkspace.State) -> [RentalOrderItemSnapshot] {
        activeRentalOrders(in: state).flatMap { rentalItems(for: $0, types: state.rentalTypes) }
    }

    private func completedRentalItems(in state: ShiftWorkspace.State) -> [RentalOrderItemSnapshot] {
        completedRentalOrders(in: state).flatMap { rentalItems(for: $0, types: state.rentalTypes) }
    }

    private func completedRentalTypeLines(in state: ShiftWorkspace.State) -> [String] {
        let completedItems = completedRentalItems(in: state)
        var lines = state.rentalTypes.map { type -> String in
            let count = completedItems.filter { rentalItem($0, matches: type) }.count
            return "\(completedRentalLineTitle(for: type)): \(count)"
        }

        let remainingItems = completedItems.filter { item in
            !state.rentalTypes.contains { type in rentalItem(item, matches: type) }
        }
        let remainingGroups = Dictionary(grouping: remainingItems) { item in
            completedRentalLineTitle(name: item.rentalTypeNameSnapshot, code: item.rentalTypeCodeSnapshot)
        }

        lines.append(
            contentsOf: remainingGroups.keys.sorted().map { title in
                "\(title): \(remainingGroups[title]?.count ?? 0)"
            }
        )
        return lines
    }

    private func rentalItem(_ item: RentalOrderItemSnapshot, matches type: RentalType) -> Bool {
        item.rentalTypeID == type.id || item.rentalTypeNameSnapshot == type.name
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

    private func activeRentalQuantity(in state: ShiftWorkspace.State) -> Int {
        activeRentalOrders(in: state).reduce(0) { $0 + $1.quantity }
    }

    private func souvenirQuantity(in state: ShiftWorkspace.State) -> Int {
        state.souvenirSales.reduce(0) { $0 + $1.quantity }
    }

    private func closeEquipmentRows(in state: ShiftWorkspace.State) -> [ShiftWorkspace.CloseShiftManualRowViewModel] {
        state.rentalTypes.map { type in
            .init(
                title: reportRentalTitle(for: type.name, code: type.code),
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
            "Дата: \(formattedReportDate(state.shift.openedAt))",
            "Открыта: \(formattedTime(state.shift.openedAt))",
            "Длительность: \(shiftDurationText(from: state.shift))",
            "Сдано объектов: \(completedRentalQuantity(in: state))",
            "Продано сувенирки: \(souvenirQuantity(in: state))",
            "Штрафов: \(state.fines.count)",
            "Текущая выручка: \(reportMoneyText(total))"
        ]
    }

    private func temporaryPaymentLines(in state: ShiftWorkspace.State) -> [String] {
        let payments = paymentTotals(in: state)

        return [
            "Оплата",
            "Наличка: \(reportMoneyText(payments.cash))",
            "Карта: \(reportMoneyText(payments.card))",
            "Перевод: \(reportMoneyText(payments.transfer))"
        ]
    }

    private func temporaryEmployeeLines(in state: ShiftWorkspace.State) -> [String] {
        let participants = state.shift.participants.sorted { lhs, rhs in
            if lhs.joinedAt != rhs.joinedAt {
                return lhs.joinedAt < rhs.joinedAt
            }
            return lhs.displayNameSnapshot < rhs.displayNameSnapshot
        }

        guard !participants.isEmpty else {
            return [
                "Сотрудники",
                "Сотрудников в смене нет"
            ]
        }

        return ["Сотрудники"] + participants.map { participant in
            let exitText = participant.leftAt.map {
                "ушел в \(formattedTime($0))"
            } ?? "еще на смене"
            return "\(participant.displayNameSnapshot) пришел в \(formattedTime(participant.joinedAt)), \(exitText)"
        }
    }

    private func temporaryRentalLines(in state: ShiftWorkspace.State) -> [String] {
        let orders = state.rentalOrders.sorted { lhs, rhs in
            lhs.startedAt < rhs.startedAt
        }

        guard !orders.isEmpty else {
            return ["Прокатов пока нет"]
        }

        return ["Прокат по операциям"] + orders.enumerated().map { index, order in
            let items = rentalItemsText(for: order, types: state.rentalTypes)
            let statusText: String
            let paymentText: String

            switch order.status {
            case .active:
                statusText = "плавает до \(formattedTime(order.expectedEndAt))"
                paymentText = "оплата при сдаче"
            case .completed:
                statusText = "сдано \(formattedTime(order.finishedAt ?? order.startedAt))"
                paymentText = order.paymentMethod.workspaceTitle
            case .canceled:
                statusText = "отменено \(formattedTime(order.canceledAt ?? order.startedAt))"
                paymentText = order.paymentMethod.workspaceTitle
            }

            return "\(index + 1). \(formattedTime(order.startedAt)) · \(statusText) · \(items) · \(reportMoneyText(order.totalPrice)) · \(paymentText)"
        }
    }

    private func temporarySouvenirRows(in state: ShiftWorkspace.State) -> [ShiftWorkspace.ReportRowViewModel] {
        state.souvenirSales
            .sorted { $0.soldAt < $1.soldAt }
            .map { sale in
                .init(
                    title: sale.itemName,
                    detail: "\(formattedTime(sale.soldAt)) · \(sale.quantity) шт. · \(sale.paymentMethod.workspaceTitle)",
                    amount: reportMoneyText(sale.totalPrice),
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
                    detail: "\(formattedTime(fine.createdAt)) · 1 шт. · \(fine.paymentMethod.workspaceTitle)",
                    amount: reportMoneyText(fine.amount),
                    quantityAdjustment: nil
                )
            }
    }

    private func rentalReportBreakdownRows(in state: ShiftWorkspace.State) -> [RentalReportBreakdownRow] {
        var rows = state.rentalTypes.map { type in
            RentalReportBreakdownRow(
                typeID: type.id,
                typeName: type.name,
                title: reportRentalTitle(for: type.name, code: type.code),
                count: 0,
                amount: .zero
            )
        }

        completedRentalOrders(in: state).forEach { order in
            let items = rentalItems(for: order, types: state.rentalTypes)

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
                title: reportRentalTitle(for: typeName, code: code),
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
            "Дата: \(formattedReportDate(state.shift.openedAt))",
            "Точка: \(state.shift.point.name)",
            "Открыта: \(formattedTime(state.shift.openedAt))",
            "Погода: не заполнено",
            "Общая выручка: \(reportMoneyText(total))",
            "",
            "Прокат",
            "Сдано объектов: \(completedRentalQuantity(in: state))",
            "Выручка по сдачам: \(reportMoneyText(rentalTotal))"
        ]
        lines += rentalRows.map { row in
            "\(row.title): \(row.count) - \(reportMoneyText(row.amount))"
        }
        lines += [
            "",
            "Оплата",
            "Наличка: \(reportMoneyText(payments.cash))",
            "Карта: \(reportMoneyText(payments.card))",
            "Перевод: \(reportMoneyText(payments.transfer))",
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
            "",
            "Рабочее оборудование",
            "Статус: заполняется вручную при закрытии смены",
            "",
            "Батарейки",
            "Статус: заполняются вручную при закрытии смены"
        ]
        return lines
    }

    private func payrollLines(in state: ShiftWorkspace.State) -> [String] {
        guard let payrollSummary = payrollSummary(in: state) else {
            return [
                "ЗП общее: \(reportMoneyText(.zero))"
            ]
        }

        let employeeLines = payrollSummary.rows.map { row in
            "\(shortEmployeeName(row.employeeName)): \(reportMoneyText(row.amount))"
        }

        return [
            "ЗП общее: \(reportMoneyText(payrollSummary.totalAmount))"
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

    private func paymentBreakdownText(_ rows: [(PaymentMethod, Money)]) -> String {
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

    private func souvenirFinalReportLines(in state: ShiftWorkspace.State) -> [String] {
        let rows = groupedOperationRows(
            records: state.souvenirSales,
            title: \.itemName,
            amount: \.totalPrice,
            count: \.quantity
        )
        let total = Money.sum(state.souvenirSales.map(\.totalPrice))

        guard !rows.isEmpty else {
            return [
                "Продаж сувенирки нет",
                "Итого: \(reportMoneyText(total))"
            ]
        }

        return rows.map { row in
            "- \(row.title) — \(row.count) — \(reportMoneyText(row.amount))"
        } + [
            "Итого: \(reportMoneyText(total))"
        ]
    }

    private func fineFinalReportLines(in state: ShiftWorkspace.State) -> [String] {
        let rows = groupedOperationRows(
            records: state.fines,
            title: \.title,
            amount: \.amount
        )
        let total = Money.sum(state.fines.map(\.amount))

        guard !rows.isEmpty else {
            return [
                "Штрафов нет",
                "Итого: \(reportMoneyText(total))"
            ]
        }

        return rows.map { row in
            "- \(row.title) — \(row.count) — \(reportMoneyText(row.amount))"
        } + [
            "Итого: \(reportMoneyText(total))"
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

    private func reportRentalTitle(for name: String, code: String) -> String {
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

    private func shortEmployeeName(_ fullName: String) -> String {
        let parts = fullName.split(separator: " ").map(String.init)
        guard parts.count > 1 else {
            return fullName
        }
        return parts[1]
    }

    private func shiftDurationText(from shift: Shift) -> String {
        let minutes = max(0, Int(dateProvider.now.timeIntervalSince(shift.openedAt) / 60))
        return "\(minutes / 60) ч \(minutes % 60) мин"
    }

    private func formattedReportDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        AppDateFormatter.time(date)
    }

    private func rentalIconText(for type: RentalType) -> String {
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

    private func rentalIconText(for item: RentalOrderItemSnapshot, types: [RentalType]) -> String {
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

    private func rentalItemsText(for order: RentalOrder, types: [RentalType]) -> String {
        rentalItems(for: order, types: types)
            .map { item in
                let tariff = tariffText(for: item)
                return "\(rentalIconText(for: item, types: types)) \(item.rentalTypeNameSnapshot) №\(item.displayNumber) · \(tariff)"
            }
            .joined(separator: ", ")
    }

    private func rentalItems(for order: RentalOrder, types: [RentalType]) -> [RentalOrderItemSnapshot] {
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

    private func moneyText(_ money: Money) -> String {
        moneyFormatter.string(from: money, includesCurrencySymbol: true)
    }

    private func reportMoneyText(_ money: Money) -> String {
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

    private func tariffText(for tariff: RentalTariff?) -> String {
        guard let tariff else { return "тариф не настроен" }
        return "\(moneyText(tariff.price)) за \(tariff.title)"
    }

    private func tariffText(for item: RentalOrderItemSnapshot) -> String {
        guard let title = item.tariffTitleSnapshot, let price = item.tariffPriceSnapshot else {
            return "тариф не сохранен"
        }
        return "\(moneyText(price)) за \(title)"
    }

    private func completedRentalLineTitle(for type: RentalType) -> String {
        completedRentalLineTitle(name: type.name, code: type.code)
    }

    private func completedRentalLineTitle(name: String, code: String) -> String {
        switch code {
        case "duck":
            return "Уточек сдано"
        case "sail":
            return "Парусников сдано"
        case "boat":
            return "Катеров сдано"
        case "fireboat":
            return "Пожарников сдано"
        default:
            return "\(name) сдано"
        }
    }
}
