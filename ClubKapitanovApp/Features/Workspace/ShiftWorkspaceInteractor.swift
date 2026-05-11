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
    func createRentalOrder(_ selections: [ShiftWorkspace.RentalOrderItemInput], paymentMethod: PaymentMethod)
    func editRentalOrder(id: UUID, selections: [ShiftWorkspace.RentalOrderItemInput], paymentMethod: PaymentMethod)
    func completeRentalOrder(id: UUID)
    func extendRentalOrder(id: UUID)
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
        static let extensionMinutes = 20
    }

    private enum CloseShiftSaving {
        static let timeoutNanoseconds: UInt64 = 12_000_000_000
    }

    private enum CloseShiftSaveError: LocalizedError {
        case noInternet
        case timeout

        var errorDescription: String? {
            userMessage
        }

        var userMessage: String {
            switch self {
            case .noInternet:
                return "Нет интернета. Смену нельзя закрыть."
            case .timeout:
                return "Сохранение отчета заняло больше 12 секунд. Смена осталась открытой."
            }
        }
    }

    @MainActor
    private final class SaveContinuationGate {
        private var didResume = false

        func resume(
            _ continuation: CheckedContinuation<Void, Error>,
            with result: Result<Void, Error>
        ) -> Bool {
            guard !didResume else { return false }
            didResume = true

            switch result {
            case .success:
                continuation.resume(returning: ())
            case let .failure(error):
                continuation.resume(throwing: error)
            }

            return true
        }
    }

    /// Локальный state экрана. После каждой операции он синхронизируется с
    /// `ShiftRepository`, чтобы будущий persistence-слой мог сохранять изменения
    /// без переписывания UI.
    private var state: ShiftWorkspace.State
    private let authRepository: AuthRepository
    private let shiftRepository: ShiftRepository
    private let reportRepository: ReportRepository
    private let shiftReportWriter: FirebaseShiftReportWriting
    private let connectivityChecker: ConnectivityChecking
    private let buildShiftCloseReportUseCase: BuildShiftCloseReportUseCase
    private let dateProvider: DateProviding
    private let presenter: ShiftWorkspacePresentationLogic
    private let router: ShiftWorkspaceRoutingLogic
    private let moneyFormatter = RubleMoneyFormatter()
    private var isClosingShift = false
    private var activeCloseShiftAttemptID: UUID?

    init(
        shift: Shift,
        rentalTypes: [RentalType],
        souvenirProducts: [SouvenirProduct],
        fineTemplates: [FineTemplate],
        batteryItems: [BatteryItem],
        authRepository: AuthRepository,
        shiftRepository: ShiftRepository,
        reportRepository: ReportRepository,
        shiftReportWriter: FirebaseShiftReportWriting,
        connectivityChecker: ConnectivityChecking,
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
            batteryItems: batteryItems,
            rentalOrders: shift.rentalOrders,
            souvenirSales: shift.souvenirSales,
            fines: shift.fines,
            selectedSection: .souvenirs
        )
        self.authRepository = authRepository
        self.shiftRepository = shiftRepository
        self.reportRepository = reportRepository
        self.shiftReportWriter = shiftReportWriter
        self.connectivityChecker = connectivityChecker
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

        authRepository.getUser(pinCode: normalizedPIN) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(user):
                self.addParticipantIfAllowed(user)
            case let .failure(error):
                self.presenter.present(
                    feedback: .init(
                        title: "PIN не проверен",
                        message: self.authErrorMessage(error)
                    )
                )
            }
        }
    }

    private func addParticipantIfAllowed(_ user: User?) {
        guard let user else {
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

    private func authErrorMessage(_ error: Error) -> String {
        if let repositoryError = error as? FirebaseUserRepositoryError,
           let description = repositoryError.errorDescription {
            return description
        }

        return "Не удалось проверить сотрудника. Проверьте интернет и попробуйте снова."
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

    func createRentalOrder(_ selections: [ShiftWorkspace.RentalOrderItemInput], paymentMethod: PaymentMethod) {
        guard let validSelections = validatedRentalSelections(
            selections,
            excludingOrderID: nil
        ) else { return }

        let now = dateProvider.now
        guard let order = makeActiveRentalOrder(
            items: validSelections,
            startedAt: now,
            paymentMethod: paymentMethod
        ) else {
            presenter.present(
                feedback: .init(
                    title: "Не выбрано",
                    message: "Добавьте хотя бы один объект с номером от 1 до 99."
                )
            )
            return
        }
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

    func editRentalOrder(
        id: UUID,
        selections: [ShiftWorkspace.RentalOrderItemInput],
        paymentMethod: PaymentMethod
    ) {
        guard let orderIndex = state.rentalOrders.firstIndex(where: { order in
            order.id == id && order.status == .active
        }) else {
            return
        }

        guard let validSelections = validatedRentalSelections(
            selections,
            excludingOrderID: id
        ) else { return }

        guard let updatedOrder = makeEditedRentalOrder(
            from: state.rentalOrders[orderIndex],
            items: validSelections,
            paymentMethod: paymentMethod
        ) else {
            presenter.present(
                feedback: .init(
                    title: "Не выбрано",
                    message: "Добавьте хотя бы один объект с номером от 1 до 99."
                )
            )
            return
        }

        state.rentalOrders[orderIndex] = updatedOrder
        persistCurrentOperations()

        presenter.present(response: .init(state: state))
        presenter.present(
            feedback: .init(
                title: "Заказ обновлен",
                message: "\(updatedOrder.quantity) объект(а), \(moneyText(updatedOrder.totalPrice)) · \(updatedOrder.paymentMethod.workspaceTitle)"
            )
        )
    }

    func completeRentalOrder(id: UUID) {
        guard let orderIndex = state.rentalOrders.firstIndex(where: { order in
            order.id == id && order.status == .active
        }) else {
            return
        }

        let completedOrder = state.rentalOrders[orderIndex].completed(
            at: dateProvider.now
        )
        state.rentalOrders[orderIndex] = completedOrder
        persistCurrentOperations()

        presenter.present(response: .init(state: state))
        presenter.present(
            feedback: .init(
                title: "Заказ завершен",
                message: "\(completedOrder.quantity) объект(а), \(moneyText(completedOrder.totalPrice)) · \(completedOrder.paymentMethod.workspaceTitle)"
            )
        )
    }

    func extendRentalOrder(id: UUID) {
        guard let orderIndex = state.rentalOrders.firstIndex(where: { order in
            order.id == id && order.status == .active
        }) else {
            return
        }

        let order = state.rentalOrders[orderIndex]
        let additionalPrice = extensionPrice(for: order)
        let extendedOrder = order.extended(
            byMinutes: RentalTiming.extensionMinutes,
            additionalPrice: additionalPrice
        )

        state.rentalOrders[orderIndex] = extendedOrder
        persistCurrentOperations()

        presenter.present(response: .init(state: state))
        presenter.present(
            feedback: .init(
                title: "Заказ продлен на 20 минут",
                message: "\(moneyText(extendedOrder.totalPrice)) / \(extendedOrder.durationMinutes) мин"
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
        guard !isClosingShift else {
            return
        }

        guard state.rentalOrders.allSatisfy({ $0.status != .active }) else {
            presenter.present(
                feedback: .init(
                    title: "Смену нельзя закрыть",
                    message: "Завершите активные заказы проката перед закрытием."
                )
            )
            return
        }

        guard connectivityChecker.hasInternetConnection else {
            presenter.present(
                feedback: .init(
                    title: "Смена не закрыта",
                    message: CloseShiftSaveError.noInternet.userMessage
                )
            )
            return
        }

        // Перед закрытием сохраняем операции, фиксируем итоговый snapshot и пишем
        // отчет в Firestore. Статус смены меняется только после успешной записи.
        persistCurrentOperations()
        let closedAt = dateProvider.now
        let attemptID = UUID()
        let closeReport = buildShiftCloseReportUseCase.execute(
            shift: state.shift,
            manualInput: manualInput,
            createdAt: closedAt,
            createdByUserID: currentEmployeeID
        )
        let payload = makeFirebaseShiftReportWritePayload(from: closeReport)
        isClosingShift = true
        activeCloseShiftAttemptID = attemptID

        Task {
            await self.saveShiftReportToFirestoreAndClose(
                payload: payload,
                closedAt: closedAt,
                attemptID: attemptID
            )
        }
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

    private func makeFirebaseShiftReportWritePayload(
        from report: ShiftCloseReport
    ) -> FirebaseShiftReportWritePayload {
        let userNameSnapshotsByUserID = makeUserNameSnapshotsByUserID()

        return FirebaseShiftReportWritePayload(
            report: report,
            rentalOrders: state.rentalOrders,
            souvenirSales: state.souvenirSales,
            fines: state.fines,
            batteryItems: state.batteryItems,
            pointNameSnapshot: state.shift.point.name,
            createdByUserNameSnapshot: userNameSnapshotsByUserID[report.createdByUserID],
            userNameSnapshotsByUserID: userNameSnapshotsByUserID
        )
    }

    private func makeUserNameSnapshotsByUserID() -> [UUID: String] {
        var snapshots: [UUID: String] = [:]

        if let userRepository = authRepository as? AdminUserRepository {
            userRepository.getAllUsers(includeArchived: true).forEach { user in
                snapshots[user.id] = user.fullName
            }
        }

        state.shift.participants.forEach { participant in
            snapshots[participant.userID] = participant.displayNameSnapshot
        }

        return snapshots
    }

    private func saveShiftReportToFirestoreAndClose(
        payload: FirebaseShiftReportWritePayload,
        closedAt: Date,
        attemptID: UUID
    ) async {
        do {
            guard connectivityChecker.hasInternetConnection else {
                throw CloseShiftSaveError.noInternet
            }

            try await saveShiftReportWithTimeout(payload)
            guard isActiveCloseShiftAttempt(attemptID) else {
                return
            }

            reportRepository.saveCloseReport(payload.report)
            _ = shiftRepository.closeShift(id: payload.report.shiftID, closedAt: closedAt)
            isClosingShift = false
            activeCloseShiftAttemptID = nil
            router.routeToLogin()
        } catch {
            guard isActiveCloseShiftAttempt(attemptID) else {
                return
            }

            isClosingShift = false
            activeCloseShiftAttemptID = nil
            presenter.present(
                feedback: .init(
                    title: "Смена не закрыта",
                    message: closeShiftSaveFailureMessage(error)
                )
            )
        }
    }

    private func saveShiftReportWithTimeout(
        _ payload: FirebaseShiftReportWritePayload
    ) async throws {
        let writer = shiftReportWriter
        let gate = SaveContinuationGate()

        try await withCheckedThrowingContinuation { continuation in
            let saveTask = Task { @MainActor in
                do {
                    try await writer.saveShiftReport(payload)
                    _ = gate.resume(continuation, with: .success(()))
                } catch {
                    _ = gate.resume(continuation, with: .failure(error))
                }
            }

            Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: CloseShiftSaving.timeoutNanoseconds)
                    if gate.resume(continuation, with: .failure(CloseShiftSaveError.timeout)) {
                        saveTask.cancel()
                    }
                } catch {
                    return
                }
            }
        }
    }

    private func isActiveCloseShiftAttempt(_ attemptID: UUID) -> Bool {
        isClosingShift && activeCloseShiftAttemptID == attemptID
    }

    private func closeShiftSaveFailureMessage(_ error: Error) -> String {
        if let closeShiftError = error as? CloseShiftSaveError {
            return closeShiftError.userMessage
        }

        let description = error.localizedDescription
        guard !description.isEmpty else {
            return "Не удалось сохранить отчет в Firebase. Проверьте подключение и попробуйте снова."
        }

        return "Не удалось сохранить отчет в Firebase. Смена осталась открытой. \(description)"
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

    private func validatedRentalSelections(
        _ selections: [ShiftWorkspace.RentalOrderItemInput],
        excludingOrderID: UUID?
    ) -> [(type: RentalType, number: Int)]? {
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
            return nil
        }

        if let typeWithoutTariff = validSelections.first(where: { $0.type.defaultTariff == nil })?.type {
            presenter.present(
                feedback: .init(
                    title: "Тариф не настроен",
                    message: "Для \(typeWithoutTariff.name) нет активного тарифа. Проверьте каталог точки."
                )
            )
            return nil
        }

        if let duplicateInOrder = firstDuplicate(in: validSelections) {
            presenter.present(
                feedback: .init(
                    title: "Повтор в заказе",
                    message: "Объект \(duplicateInOrder.type.name) №\(duplicateInOrder.number) уже добавлен в этот заказ."
                )
            )
            return nil
        }

        let activeItems = activeRentalItems(excluding: excludingOrderID)
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
            return nil
        }

        return validSelections
    }

    private func makeActiveRentalOrder(
        items: [(type: RentalType, number: Int)],
        startedAt: Date,
        paymentMethod: PaymentMethod
    ) -> RentalOrder? {
        guard let primaryType = items.first?.type else {
            return nil
        }

        let itemSnapshots = makeItemSnapshots(from: items)
        let selectedTariffs = itemSnapshots.compactMap(\.tariffPriceSnapshot)
        let durationMinutes = itemSnapshots.compactMap(\.tariffDurationMinutes).max() ?? RentalTiming.fallbackDurationMinutes
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
            paymentMethod: paymentMethod,
            status: .active
        )
    }

    private func makeEditedRentalOrder(
        from order: RentalOrder,
        items: [(type: RentalType, number: Int)],
        paymentMethod: PaymentMethod
    ) -> RentalOrder? {
        guard let primaryType = items.first?.type else {
            return nil
        }

        let itemSnapshots = makeItemSnapshots(from: items)
        let totalPrice = Money
            .sum(itemSnapshots.compactMap(\.tariffPriceSnapshot))
            .multiplied(by: order.rentalPeriodsCount)
        let orderName = items.count == 1 ? primaryType.name : "Смешанный заказ"

        return RentalOrder(
            id: order.id,
            rentalTypeID: primaryType.id,
            rentalTypeNameSnapshot: orderName,
            rentedAssetIDs: order.rentedAssetIDs,
            rentedAssetNumbersSnapshot: itemSnapshots.map { "\($0.displayNumber)" },
            rentedItemsSnapshot: itemSnapshots,
            createdAt: order.createdAt,
            startedAt: order.startedAt,
            expectedEndAt: order.expectedEndAt,
            finishedAt: order.finishedAt,
            canceledAt: order.canceledAt,
            durationMinutes: order.durationMinutes,
            totalPrice: totalPrice,
            rentalPeriodsCount: order.rentalPeriodsCount,
            paymentMethod: paymentMethod,
            status: order.status,
            notes: order.notes
        )
    }

    private func makeItemSnapshots(
        from items: [(type: RentalType, number: Int)]
    ) -> [RentalOrderItemSnapshot] {
        items.map { item in
            let tariff = item.type.defaultTariff
            return RentalOrderItemSnapshot(
                rentalTypeID: item.type.id,
                rentalTypeNameSnapshot: item.type.name,
                rentalTypeCodeSnapshot: item.type.code,
                displayNumber: item.number,
                rentalTariffID: tariff?.id,
                tariffTitleSnapshot: tariff?.title,
                tariffDurationMinutes: tariff?.durationMinutes,
                tariffPriceSnapshot: tariff?.price,
                payrollRateSnapshot: item.type.payrollRate
            )
        }
    }

    private func extensionPrice(for order: RentalOrder) -> Money {
        let snapshotPrices = order.rentedItemsSnapshot.compactMap(\.tariffPriceSnapshot)
        if !snapshotPrices.isEmpty {
            return Money.sum(snapshotPrices)
        }

        let completedPeriods = order.rentalPeriodsCount
        return Money(kopecks: order.totalPrice.kopecks / completedPeriods)
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

    private func activeRentalItems(excluding orderID: UUID? = nil) -> [RentalOrderItemSnapshot] {
        state.rentalOrders
            .filter { order in
                order.status == .active && order.id != orderID
            }
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
