import Foundation

/// Business layer основного рабочего экрана смены.
///
/// Interactor хранит mutable state смены, применяет бизнес-операции workspace,
/// синхронизирует их с repository и просит Presenter пересобрать ViewModel.
protocol ShiftWorkspaceBusinessLogic {
    func load()
    func select(section: ShiftWorkspaceSection)
    func addParticipant(pinCode: String)
    func removeParticipant(id: UUID)
    func createRentalOrder(_ selections: [ShiftWorkspace.RentalOrderItemInput])
    func completeRentalOrder(id: UUID, paymentMethod: PaymentMethod)
    func addSouvenir(at index: Int, quantity: Int, paymentMethod: PaymentMethod)
    func addFine(at index: Int, quantity: Int, paymentMethod: PaymentMethod)
    func increaseSouvenirQuantity(at index: Int)
    func decreaseSouvenirQuantity(at index: Int)
    func increaseFineQuantity(at index: Int)
    func decreaseFineQuantity(at index: Int)
    func closeShift(manualInput: ShiftCloseReportManualInput)
}

final class ShiftWorkspaceInteractor: ShiftWorkspaceBusinessLogic {
    private enum RentalTiming {
        static let fallbackDurationMinutes = 20
    }

    /// Локальный state экрана. После каждой операции он синхронизируется с
    /// `ShiftRepository`, чтобы будущий persistence-слой мог сохранять изменения
    /// без переписывания UI.
    private var state: ShiftWorkspace.State
    private let authRepository: AuthRepository
    private let shiftRepository: ShiftRepository
    private let reportRepository: ReportRepository
    private let buildShiftCloseReportUseCase: BuildShiftCloseReportUseCase
    private let dateProvider: DateProviding
    private let presenter: ShiftWorkspacePresentationLogic
    private let router: ShiftWorkspaceRoutingLogic
    private let moneyFormatter = RubleMoneyFormatter()

    init(
        shift: Shift,
        rentalTypes: [RentalType],
        souvenirProducts: [SouvenirProduct],
        fineTemplates: [FineTemplate],
        authRepository: AuthRepository,
        shiftRepository: ShiftRepository,
        reportRepository: ReportRepository,
        buildShiftCloseReportUseCase: BuildShiftCloseReportUseCase,
        dateProvider: DateProviding,
        presenter: ShiftWorkspacePresentationLogic,
        router: ShiftWorkspaceRoutingLogic
    ) {
        self.state = .init(
            shift: shift,
            rentalTypes: rentalTypes,
            souvenirProducts: souvenirProducts,
            fineTemplates: fineTemplates,
            rentalOrders: shift.rentalOrders,
            souvenirSales: shift.souvenirSales,
            fines: shift.fines,
            selectedSection: .souvenirs
        )
        self.authRepository = authRepository
        self.shiftRepository = shiftRepository
        self.reportRepository = reportRepository
        self.buildShiftCloseReportUseCase = buildShiftCloseReportUseCase
        self.dateProvider = dateProvider
        self.presenter = presenter
        self.router = router
    }

    func load() {
        presenter.present(response: .init(state: state))
    }

    func select(section: ShiftWorkspaceSection) {
        // Выбор раздела не меняет бизнес-данные смены, только активный UI-контекст.
        state.selectedSection = section
        presenter.present(response: .init(state: state))
    }

    func addParticipant(pinCode: String) {
        let normalizedPIN = pinCode.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedPIN.count == 4, normalizedPIN.allSatisfy(\.isNumber) else {
            presenter.present(
                feedback: .init(
                    title: "PIN не принят",
                    message: "Введите 4-значный PIN сотрудника."
                )
            )
            return
        }

        guard let user = authRepository.getUser(pinCode: normalizedPIN) else {
            presenter.present(
                feedback: .init(
                    title: "Сотрудник не найден",
                    message: "Проверьте PIN и попробуйте снова."
                )
            )
            return
        }

        guard user.role != .admin else {
            presenter.present(
                feedback: .init(
                    title: "Нельзя добавить",
                    message: "Административный доступ недоступен в рабочей смене."
                )
            )
            return
        }

        guard !state.shift.participants.contains(where: { $0.userID == user.id && $0.leftAt == nil }) else {
            presenter.present(
                feedback: .init(
                    title: "Уже в смене",
                    message: user.fullName
                )
            )
            return
        }

        let participant = ShiftParticipant(
            shiftID: state.shift.id,
            userID: user.id,
            displayNameSnapshot: user.fullName,
            roleSnapshot: user.role,
            joinedAt: dateProvider.now
        )
        let updatedShift = state.shift
            .replacingParticipants(state.shift.participants + [participant])
            .replacingOperations(
                rentalOrders: state.rentalOrders,
                souvenirSales: state.souvenirSales,
                fines: state.fines
            )

        state.shift = shiftRepository.updateShift(updatedShift)
        presenter.present(response: .init(state: state))
        presenter.present(
            feedback: .init(
                title: "Сотрудник добавлен",
                message: user.fullName
            )
        )
    }

    func removeParticipant(id: UUID) {
        let activeParticipants = state.shift.participants.filter { $0.leftAt == nil }

        guard activeParticipants.count > 1 else {
            presenter.present(
                feedback: .init(
                    title: "Нельзя удалить",
                    message: "В смене должен остаться хотя бы один сотрудник"
                )
            )
            return
        }

        guard let participantIndex = state.shift.participants.firstIndex(where: { participant in
            participant.id == id && participant.leftAt == nil
        }) else {
            return
        }

        let participant = state.shift.participants[participantIndex]
        var updatedParticipants = state.shift.participants
        updatedParticipants[participantIndex] = participant.leaving(at: dateProvider.now)

        let updatedShift = state.shift
            .replacingParticipants(updatedParticipants)
            .replacingOperations(
                rentalOrders: state.rentalOrders,
                souvenirSales: state.souvenirSales,
                fines: state.fines
            )

        state.shift = shiftRepository.updateShift(updatedShift)
        presenter.present(response: .init(state: state))
        presenter.present(
            feedback: .init(
                title: "Сотрудник удален",
                message: participant.displayNameSnapshot
            )
        )
    }

    func createRentalOrder(_ selections: [ShiftWorkspace.RentalOrderItemInput]) {
        let validSelections = selections.compactMap { selection -> (type: RentalType, number: Int)? in
            guard state.rentalTypes.indices.contains(selection.rentalTypeIndex) else { return nil }
            guard (1...99).contains(selection.number) else { return nil }
            return (state.rentalTypes[selection.rentalTypeIndex], selection.number)
        }

        guard !validSelections.isEmpty, validSelections.count == selections.count else {
            presenter.present(
                feedback: .init(
                    title: "Не выбрано",
                    message: "Добавьте хотя бы один объект с номером от 1 до 99."
                )
            )
            return
        }

        if let typeWithoutTariff = validSelections.first(where: { $0.type.defaultTariff == nil })?.type {
            presenter.present(
                feedback: .init(
                    title: "Тариф не настроен",
                    message: "Для \(typeWithoutTariff.name) нет активного тарифа. Проверьте каталог точки."
                )
            )
            return
        }

        let duplicateInOrder = firstDuplicate(in: validSelections)
        if let duplicateInOrder {
            presenter.present(
                feedback: .init(
                    title: "Повтор в заказе",
                    message: "Объект \(duplicateInOrder.type.name) №\(duplicateInOrder.number) уже добавлен в этот заказ."
                )
            )
            return
        }

        let activeItems = activeRentalItems()
        if let blocked = validSelections.first(where: { selection in
            activeItems.contains { item in
                item.rentalTypeID == selection.type.id && item.displayNumber == selection.number
            }
        }) {
            presenter.present(
                feedback: .init(
                    title: "Нельзя сдать",
                    message: alreadyFloatingText(type: blocked.type, number: blocked.number)
                )
            )
            return
        }

        let now = dateProvider.now
        let order = makeActiveRentalOrder(items: validSelections, startedAt: now)
        state.rentalOrders.append(order)
        persistCurrentOperations()

        presenter.present(response: .init(state: state))
        presenter.present(
            feedback: .init(
                title: "Заказ создан",
                message: "\(order.quantity) объект(а) отправлено в плавание"
            )
        )
    }

    func completeRentalOrder(id: UUID, paymentMethod: PaymentMethod) {
        guard let orderIndex = state.rentalOrders.firstIndex(where: { order in
            order.id == id && order.status == .active
        }) else {
            return
        }

        let completedOrder = state.rentalOrders[orderIndex].completed(
            at: dateProvider.now,
            paymentMethod: paymentMethod
        )
        state.rentalOrders[orderIndex] = completedOrder
        persistCurrentOperations()

        presenter.present(response: .init(state: state))
        presenter.present(
            feedback: .init(
                title: "Заказ завершен",
                message: "\(completedOrder.quantity) объект(а), \(moneyText(completedOrder.totalPrice)) · \(paymentMethod.workspaceTitle)"
            )
        )
    }

    func addSouvenir(at index: Int, quantity: Int, paymentMethod: PaymentMethod) {
        // Добавление сувенирки вызывается только после подтверждения количества и оплаты.
        // Одинаковые товары с одинаковой оплатой агрегируются в одну строку истории.
        guard state.souvenirProducts.indices.contains(index) else { return }
        guard quantity > 0 else { return }

        let product = state.souvenirProducts[index]
        changeSouvenirQuantity(for: product, delta: quantity, paymentMethod: paymentMethod)
        persistCurrentOperations()
        presenter.present(response: .init(state: state))
        presenter.present(
            feedback: .init(
                title: "Добавлено",
                message: "\(product.name) — \(quantity) шт. на \(moneyText(totalPrice(product.price, quantity: quantity))) · \(paymentMethod.workspaceTitle)"
            )
        )
    }

    func addFine(at index: Int, quantity: Int, paymentMethod: PaymentMethod) {
        // Штрафы хранятся как отдельные FineRecord-записи. Если пользователь добавил
        // 3 одинаковых штрафа, это три факта начисления, а не одна запись quantity=3.
        guard state.fineTemplates.indices.contains(index) else { return }
        guard quantity > 0 else { return }

        let template = state.fineTemplates[index]
        changeFineQuantity(for: template, delta: quantity, paymentMethod: paymentMethod)
        persistCurrentOperations()
        presenter.present(response: .init(state: state))
        presenter.present(
            feedback: .init(
                title: "Добавлено",
                message: "\(template.title) — \(quantity) шт. на \(moneyText(totalPrice(template.amount, quantity: quantity))) · \(paymentMethod.workspaceTitle)"
            )
        )
    }

    func increaseSouvenirQuantity(at index: Int) {
        guard state.souvenirProducts.indices.contains(index) else { return }
        changeSouvenirQuantity(for: state.souvenirProducts[index], delta: 1)
        persistCurrentOperations()
        presenter.present(response: .init(state: state))
    }

    func decreaseSouvenirQuantity(at index: Int) {
        guard state.souvenirProducts.indices.contains(index) else { return }
        changeSouvenirQuantity(for: state.souvenirProducts[index], delta: -1)
        persistCurrentOperations()
        presenter.present(response: .init(state: state))
    }

    func increaseFineQuantity(at index: Int) {
        guard state.fineTemplates.indices.contains(index) else { return }
        changeFineQuantity(for: state.fineTemplates[index], delta: 1)
        persistCurrentOperations()
        presenter.present(response: .init(state: state))
    }

    func decreaseFineQuantity(at index: Int) {
        guard state.fineTemplates.indices.contains(index) else { return }
        changeFineQuantity(for: state.fineTemplates[index], delta: -1)
        persistCurrentOperations()
        presenter.present(response: .init(state: state))
    }

    func closeShift(manualInput: ShiftCloseReportManualInput) {
        guard state.rentalOrders.allSatisfy({ $0.status != .active }) else {
            presenter.present(
                feedback: .init(
                    title: "Смену нельзя закрыть",
                    message: "Завершите активные заказы проката перед закрытием."
                )
            )
            return
        }

        // Перед закрытием сохраняем операции, фиксируем итоговый snapshot, затем
        // меняем статус смены. После этого Router сбрасывает flow на Login.
        persistCurrentOperations()
        let closedAt = dateProvider.now
        let closeReport = buildShiftCloseReportUseCase.execute(
            shift: state.shift,
            manualInput: manualInput,
            createdAt: closedAt,
            createdByUserID: currentEmployeeID
        )
        reportRepository.saveCloseReport(closeReport)
        _ = shiftRepository.closeShift(id: state.shift.id, closedAt: closedAt)
        router.routeToLogin()
    }

    private var currentEmployeeID: UUID {
        state.shift.participants.first { $0.leftAt == nil }?.userID ?? state.shift.openedByUserID
    }

    private func persistCurrentOperations() {
        state.shift = shiftRepository.updateShift(
            state.shift.replacingOperations(
                rentalOrders: state.rentalOrders,
                souvenirSales: state.souvenirSales,
                fines: state.fines
            )
        )
    }

    private func changeSouvenirQuantity(
        for product: SouvenirProduct,
        delta: Int,
        paymentMethod: PaymentMethod? = nil
    ) {
        // Сувенирка агрегируется в одну SouvenirSale на товар: +/- меняет quantity
        // и пересчитывает totalPrice. Разные способы оплаты держатся отдельно,
        // чтобы наличка в отчете была только там, где ее явно выбрали.
        guard delta != 0 else { return }

        if delta < 0 {
            removeSouvenirQuantity(for: product, quantity: abs(delta))
            return
        }

        let effectivePaymentMethod = paymentMethod ?? lastSouvenirPaymentMethod(for: product) ?? .card
        if let saleIndex = state.souvenirSales.firstIndex(where: { sale in
            (sale.productID == product.id || sale.itemName == product.name)
                && sale.paymentMethod == effectivePaymentMethod
        }) {
            let sale = state.souvenirSales[saleIndex]
            let updatedQuantity = sale.quantity + delta

            state.souvenirSales[saleIndex] = SouvenirSale(
                id: sale.id,
                productID: product.id,
                itemName: product.name,
                quantity: updatedQuantity,
                unitPrice: product.price,
                totalPrice: totalPrice(product.price, quantity: updatedQuantity),
                soldAt: sale.soldAt,
                soldByEmployeeID: sale.soldByEmployeeID,
                paymentMethod: effectivePaymentMethod,
                notes: sale.notes
            )
            return
        }

        let sale = SouvenirSale(
            productID: product.id,
            itemName: product.name,
            quantity: delta,
            unitPrice: product.price,
            totalPrice: totalPrice(product.price, quantity: delta),
            soldAt: dateProvider.now,
            soldByEmployeeID: currentEmployeeID,
            paymentMethod: effectivePaymentMethod
        )
        state.souvenirSales.append(sale)
    }

    private func removeSouvenirQuantity(for product: SouvenirProduct, quantity: Int) {
        var remainingQuantity = quantity

        while remainingQuantity > 0 {
            guard let saleIndex = state.souvenirSales.lastIndex(where: { sale in
                sale.productID == product.id || sale.itemName == product.name
            }) else {
                return
            }

            let sale = state.souvenirSales[saleIndex]
            let removedQuantity = min(remainingQuantity, sale.quantity)
            let updatedQuantity = sale.quantity - removedQuantity
            remainingQuantity -= removedQuantity

            guard updatedQuantity > 0 else {
                state.souvenirSales.remove(at: saleIndex)
                continue
            }

            state.souvenirSales[saleIndex] = SouvenirSale(
                id: sale.id,
                productID: sale.productID,
                itemName: sale.itemName,
                quantity: updatedQuantity,
                unitPrice: sale.unitPrice,
                totalPrice: totalPrice(sale.unitPrice, quantity: updatedQuantity),
                soldAt: sale.soldAt,
                soldByEmployeeID: sale.soldByEmployeeID,
                paymentMethod: sale.paymentMethod,
                notes: sale.notes
            )
        }
    }

    private func lastSouvenirPaymentMethod(for product: SouvenirProduct) -> PaymentMethod? {
        state.souvenirSales.last { sale in
            sale.productID == product.id || sale.itemName == product.name
        }?.paymentMethod
    }

    private func changeFineQuantity(
        for template: FineTemplate,
        delta: Int,
        paymentMethod: PaymentMethod? = nil
    ) {
        // Для штрафов +/- добавляет или удаляет отдельные FineRecord. Удаляем последнюю
        // подходящую запись, чтобы поведение было ожидаемым для пользователя.
        guard delta != 0 else { return }

        if delta > 0 {
            let effectivePaymentMethod = paymentMethod ?? lastFinePaymentMethod(for: template) ?? .card
            let createdAt = dateProvider.now
            (0..<delta).forEach { _ in
                state.fines.append(
                    makeFine(
                        from: template,
                        createdAt: createdAt,
                        paymentMethod: effectivePaymentMethod
                    )
                )
            }
            return
        }

        (0..<abs(delta)).forEach { _ in
            guard let fineIndex = state.fines.lastIndex(where: { fine in
                fine.templateID == template.id || fine.title == template.title
            }) else { return }
            state.fines.remove(at: fineIndex)
        }
    }

    private func lastFinePaymentMethod(for template: FineTemplate) -> PaymentMethod? {
        state.fines.last { fine in
            fine.templateID == template.id || fine.title == template.title
        }?.paymentMethod
    }

    private func makeFine(
        from template: FineTemplate,
        createdAt: Date,
        paymentMethod: PaymentMethod
    ) -> FineRecord {
        FineRecord(
            templateID: template.id,
            title: template.title,
            amount: template.amount,
            createdAt: createdAt,
            createdByEmployeeID: currentEmployeeID,
            paymentMethod: paymentMethod
        )
    }

    private func makeActiveRentalOrder(
        items: [(type: RentalType, number: Int)],
        startedAt: Date
    ) -> RentalOrder {
        let itemSnapshots = items.map { item in
            let tariff = item.type.defaultTariff
            return RentalOrderItemSnapshot(
                rentalTypeID: item.type.id,
                rentalTypeNameSnapshot: item.type.name,
                rentalTypeCodeSnapshot: item.type.code,
                displayNumber: item.number,
                rentalTariffID: tariff?.id,
                tariffTitleSnapshot: tariff?.title,
                tariffDurationMinutes: tariff?.durationMinutes,
                tariffPriceSnapshot: tariff?.price
            )
        }
        let selectedTariffs = itemSnapshots.compactMap(\.tariffPriceSnapshot)
        let durationMinutes = itemSnapshots.compactMap(\.tariffDurationMinutes).max() ?? RentalTiming.fallbackDurationMinutes
        let primaryType = items[0].type
        let orderName = items.count == 1 ? primaryType.name : "Смешанный заказ"
        let expectedDuration = TimeInterval(durationMinutes * 60)

        return RentalOrder(
            rentalTypeID: primaryType.id,
            rentalTypeNameSnapshot: orderName,
            rentedAssetNumbersSnapshot: itemSnapshots.map { "\($0.displayNumber)" },
            rentedItemsSnapshot: itemSnapshots,
            createdAt: startedAt,
            startedAt: startedAt,
            expectedEndAt: startedAt.addingTimeInterval(expectedDuration),
            finishedAt: nil,
            durationMinutes: durationMinutes,
            totalPrice: Money.sum(selectedTariffs),
            paymentMethod: .card,
            status: .active
        )
    }

    private func firstDuplicate(
        in selections: [(type: RentalType, number: Int)]
    ) -> (type: RentalType, number: Int)? {
        var seen = Set<String>()

        for selection in selections {
            let key = "\(selection.type.id.uuidString)-\(selection.number)"
            guard !seen.contains(key) else {
                return selection
            }
            seen.insert(key)
        }

        return nil
    }

    private func activeRentalItems() -> [RentalOrderItemSnapshot] {
        state.rentalOrders
            .filter { $0.status == .active }
            .flatMap(\.rentedItemsSnapshot)
    }

    private func alreadyFloatingText(type: RentalType, number: Int) -> String {
        let title = type.name.lowercased()
        let pronoun = title.hasSuffix("а") || title.hasSuffix("я") ? "она" : "он"
        return "Нельзя сдать \(title) №\(number), так как \(pronoun) уже плавает."
    }

    private func totalPrice(_ unitPrice: Money, quantity: Int) -> Money {
        unitPrice.multiplied(by: quantity)
    }

    private func moneyText(_ money: Money) -> String {
        moneyFormatter.string(from: money, includesCurrencySymbol: true)
    }
}
