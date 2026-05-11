import FirebaseFirestore
import Foundation

nonisolated final class FirestoreShiftReportRepository: FirebaseShiftReportWriting {
    private enum Constants {
        static let maxTransactionWrites = 500
        static let singletonDocumentID = "current"
    }

    private enum Collection {
        static let points = "points"
        static let shiftReports = "shiftReports"
        static let souvenirs = "souvenirs"
        static let batteryTypes = "batteryTypes"
        static let rentalOrders = "rentalOrders"
        static let rentalSummary = "rentalSummary"
        static let souvenirSales = "souvenirSales"
        static let souvenirSummary = "souvenirSummary"
        static let fines = "fines"
        static let fineSummary = "fineSummary"
        static let payroll = "payroll"
        static let equipmentSnapshot = "equipmentSnapshot"
        static let batterySnapshot = "batterySnapshot"
    }

    private enum Field {
        static let inventoryAppliedAt = "inventoryAppliedAt"
        static let stockQuantity = "stockQuantity"
        static let updatedAt = "updatedAt"
    }

    private struct InventoryStockUpdate {
        let reference: DocumentReference
        let stockQuantity: Int
    }

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func saveShiftReport(_ report: ShiftCloseReport) async throws {
        try await saveShiftReport(FirebaseShiftReportWritePayload(report: report))
    }

    func saveShiftReport(_ payload: FirebaseShiftReportWritePayload) async throws {
        try validateWriteCount(for: payload)

        let reportReference = db
            .collection(Collection.shiftReports)
            .document(payload.reportID)

        // Close shift must not use Firestore's offline write queue: transactions
        // require an online commit and fail instead of silently replaying later.
        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                try self.writeShiftReportAndInventory(
                    payload: payload,
                    reportReference: reportReference,
                    transaction: transaction
                )
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    nonisolated private func writeShiftReportAndInventory(
        payload: FirebaseShiftReportWritePayload,
        reportReference: DocumentReference,
        transaction: Transaction
    ) throws {
        let reportSnapshot = try transaction.getDocument(reportReference)
        let inventoryAlreadyApplied = reportSnapshot.data()?[Field.inventoryAppliedAt] != nil
        let inventoryUpdates: [InventoryStockUpdate] = inventoryAlreadyApplied
            ? []
            : try makeInventoryStockUpdates(payload: payload, transaction: transaction)

        // Retries after a client timeout write the same report document, but must
        // not decrement inventory again if the previous transaction actually committed.
        try writeShiftReport(
            payload: payload,
            reportReference: reportReference,
            transaction: transaction,
            inventoryAppliedAt: inventoryAlreadyApplied ? existingInventoryAppliedAt(from: reportSnapshot) : payload.report.createdAt
        )

        if !inventoryAlreadyApplied {
            applyInventoryStockUpdates(
                inventoryUpdates,
                updatedAt: payload.report.createdAt,
                transaction: transaction
            )
        }
    }

    nonisolated private func writeShiftReport(
        payload: FirebaseShiftReportWritePayload,
        reportReference: DocumentReference,
        transaction: Transaction,
        inventoryAppliedAt: Date?
    ) throws {
        let report = payload.report

        try transaction.setData(
            from: FirebaseShiftReportMapper.makeDTO(
                from: report,
                reportID: payload.reportID,
                reportNumber: payload.reportNumber,
                pointNameSnapshot: payload.pointNameSnapshot,
                userNameSnapshot: payload.createdByUserNameSnapshot,
                paymentRevenue: makePaymentRevenue(from: payload),
                inventoryAppliedAt: inventoryAppliedAt,
                textReport: payload.textReport
            ),
            forDocument: reportReference
        )

        try saveRentalOrders(payload.rentalOrders, reportReference: reportReference, transaction: transaction)
        try saveRentalSummary(report.rentalSummary, reportReference: reportReference, transaction: transaction)
        try saveSouvenirSales(
            payload.souvenirSales,
            payload: payload,
            reportReference: reportReference,
            transaction: transaction
        )
        try saveSouvenirSummary(report.souvenirSummary, reportReference: reportReference, transaction: transaction)
        try saveFines(payload.fines, payload: payload, reportReference: reportReference, transaction: transaction)
        try saveFineSummary(report.finesSummary, reportReference: reportReference, transaction: transaction)
        try savePayroll(report.payrollSummary, reportReference: reportReference, transaction: transaction)
        try saveEquipmentSnapshot(report.equipmentSnapshot, reportReference: reportReference, transaction: transaction)
        try saveBatterySnapshot(report.batterySnapshot, reportReference: reportReference, transaction: transaction)
    }

    nonisolated private func makeInventoryStockUpdates(
        payload: FirebaseShiftReportWritePayload,
        transaction: Transaction
    ) throws -> [InventoryStockUpdate] {
        var updates: [InventoryStockUpdate] = []
        let pointReference = db
            .collection(Collection.points)
            .document(payload.report.pointID.uuidString)

        try souvenirStockAdjustmentByProductID(from: payload.souvenirSales).forEach { productID, soldQuantity in
            let reference = pointReference
                .collection(Collection.souvenirs)
                .document(productID.uuidString)
            let snapshot = try transaction.getDocument(reference)
            let currentQuantity = try stockQuantity(from: snapshot, path: reference.path)

            updates.append(
                InventoryStockUpdate(
                    reference: reference,
                    stockQuantity: max(0, currentQuantity - soldQuantity)
                )
            )
        }

        try batteryStockQuantityByID(
            rows: payload.report.batterySnapshot.workingRows,
            batteryItems: payload.batteryItems
        ).forEach { batteryID, stockQuantity in
            let reference = pointReference
                .collection(Collection.batteryTypes)
                .document(batteryID.uuidString)
            let snapshot = try transaction.getDocument(reference)
            _ = try self.stockQuantity(from: snapshot, path: reference.path)

            updates.append(
                InventoryStockUpdate(
                    reference: reference,
                    stockQuantity: max(0, stockQuantity)
                )
            )
        }

        return updates
    }

    nonisolated private func applyInventoryStockUpdates(
        _ updates: [InventoryStockUpdate],
        updatedAt: Date,
        transaction: Transaction
    ) {
        updates.forEach { update in
            transaction.updateData(
                [
                    Field.stockQuantity: update.stockQuantity,
                    Field.updatedAt: updatedAt
                ],
                forDocument: update.reference
            )
        }
    }

    nonisolated private func makePaymentRevenue(
        from payload: FirebaseShiftReportWritePayload
    ) -> [FirebaseShiftReportDTO.PaymentRevenue] {
        var amountsByPaymentMethod: [PaymentMethod: Money] = [:]

        payload.rentalOrders
            .filter { $0.status == .completed }
            .forEach { order in
                amountsByPaymentMethod[order.paymentMethod, default: .zero] += order.totalPrice
            }

        payload.souvenirSales.forEach { sale in
            amountsByPaymentMethod[sale.paymentMethod, default: .zero] += sale.totalPrice
        }

        payload.fines.forEach { fine in
            amountsByPaymentMethod[fine.paymentMethod, default: .zero] += fine.amount
        }

        let paymentRevenue: [FirebaseShiftReportDTO.PaymentRevenue] = PaymentMethod.allCases.reduce(into: []) { result, paymentMethod in
            guard let amount = amountsByPaymentMethod[paymentMethod] else {
                return
            }

            result.append(
                FirebaseShiftReportDTO.PaymentRevenue(
                    paymentMethod: paymentMethod.rawValue,
                    amountKopecks: amount.kopecks
                )
            )
        }

        guard !paymentRevenue.isEmpty else {
            return payload.report.rentalSummary.payments.map {
                FirebaseShiftReportDTO.PaymentRevenue(
                    paymentMethod: $0.paymentMethod.rawValue,
                    amountKopecks: $0.amount.kopecks
                )
            }
        }

        return paymentRevenue
    }

    nonisolated private func existingInventoryAppliedAt(from snapshot: DocumentSnapshot) -> Date? {
        let rawValue = snapshot.data()?[Field.inventoryAppliedAt]

        if let date = rawValue as? Date {
            return date
        }

        if let timestamp = rawValue as? Timestamp {
            return timestamp.dateValue()
        }

        return nil
    }

    nonisolated private func souvenirStockAdjustmentByProductID(
        from sales: [SouvenirSale]
    ) -> [UUID: Int] {
        sales.reduce(into: [:]) { result, sale in
            guard let productID = sale.productID else {
                return
            }

            result[productID, default: 0] += max(0, sale.quantity)
        }
    }

    nonisolated private func batteryStockQuantityByID(
        rows: [ShiftBatteryCountRow],
        batteryItems: [BatteryItem]
    ) throws -> [UUID: Int] {
        let batteryItemsByTitle = Dictionary(
            batteryItems.map { ($0.title, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return try rows.reduce(into: [:]) { result, row in
            guard let item = batteryItemsByTitle[row.title] else {
                throw FirestoreShiftReportRepositoryError.missingBatteryCatalogItem(title: row.title)
            }

            result[item.id] = max(0, row.count)
        }
    }

    nonisolated private func stockQuantity(
        from snapshot: DocumentSnapshot,
        path: String
    ) throws -> Int {
        guard snapshot.exists else {
            throw FirestoreShiftReportRepositoryError.missingInventoryDocument(path: path)
        }

        let value = snapshot.data()?[Field.stockQuantity]
        if let int = value as? Int {
            return int
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        throw FirestoreShiftReportRepositoryError.invalidStockQuantity(path: path)
    }

    nonisolated private func saveRentalOrders(
        _ orders: [RentalOrder],
        reportReference: DocumentReference,
        transaction: Transaction
    ) throws {
        let collection = reportReference.collection(Collection.rentalOrders)

        try orders.forEach { order in
            try transaction.setData(
                from: FirebaseRentalOrderMapper.makeDTO(from: order),
                forDocument: collection.document(order.id.uuidString)
            )
        }
    }

    nonisolated private func saveRentalSummary(
        _ summary: ShiftRentalCloseSummary,
        reportReference: DocumentReference,
        transaction: Transaction
    ) throws {
        try transaction.setData(
            from: FirebaseRentalSummaryMapper.makeDTO(from: summary),
            forDocument: singletonDocument(
                Collection.rentalSummary,
                reportReference: reportReference
            )
        )
    }

    nonisolated private func saveSouvenirSales(
        _ sales: [SouvenirSale],
        payload: FirebaseShiftReportWritePayload,
        reportReference: DocumentReference,
        transaction: Transaction
    ) throws {
        let collection = reportReference.collection(Collection.souvenirSales)

        try sales.forEach { sale in
            try transaction.setData(
                from: FirebaseSouvenirSaleMapper.makeDTO(
                    from: sale,
                    userNameSnapshot: payload.userNameSnapshot(for: sale.soldByEmployeeID)
                ),
                forDocument: collection.document(sale.id.uuidString)
            )
        }
    }

    nonisolated private func saveSouvenirSummary(
        _ summary: ShiftSouvenirCloseSummary,
        reportReference: DocumentReference,
        transaction: Transaction
    ) throws {
        try transaction.setData(
            from: FirebaseSouvenirSummaryMapper.makeDTO(from: summary),
            forDocument: singletonDocument(
                Collection.souvenirSummary,
                reportReference: reportReference
            )
        )
    }

    nonisolated private func saveFines(
        _ fines: [FineRecord],
        payload: FirebaseShiftReportWritePayload,
        reportReference: DocumentReference,
        transaction: Transaction
    ) throws {
        let collection = reportReference.collection(Collection.fines)

        try fines.forEach { fine in
            try transaction.setData(
                from: FirebaseFineMapper.makeDTO(
                    from: fine,
                    userNameSnapshot: payload.userNameSnapshot(for: fine.createdByEmployeeID)
                ),
                forDocument: collection.document(fine.id.uuidString)
            )
        }
    }

    nonisolated private func saveFineSummary(
        _ summary: ShiftFinesCloseSummary,
        reportReference: DocumentReference,
        transaction: Transaction
    ) throws {
        try transaction.setData(
            from: FirebaseFineSummaryMapper.makeDTO(from: summary),
            forDocument: singletonDocument(
                Collection.fineSummary,
                reportReference: reportReference
            )
        )
    }

    nonisolated private func savePayroll(
        _ summary: ShiftPayrollCloseSummary?,
        reportReference: DocumentReference,
        transaction: Transaction
    ) throws {
        let dto: FirebasePayrollDTO
        if let summary {
            dto = FirebasePayrollMapper.makeDTO(from: summary)
        } else {
            dto = FirebasePayrollDTO(
                ratePerTripKopecks: 0,
                totalTripsCount: 0,
                totalFundKopecks: 0,
                totalAmountKopecks: 0,
                payrollSnapshot: []
            )
        }

        try transaction.setData(
            from: dto,
            forDocument: singletonDocument(
                Collection.payroll,
                reportReference: reportReference
            )
        )
    }

    nonisolated private func saveEquipmentSnapshot(
        _ snapshot: ShiftEquipmentSnapshot,
        reportReference: DocumentReference,
        transaction: Transaction
    ) throws {
        try transaction.setData(
            from: FirebaseEquipmentSnapshotMapper.makeDTO(from: snapshot),
            forDocument: singletonDocument(
                Collection.equipmentSnapshot,
                reportReference: reportReference
            )
        )
    }

    nonisolated private func saveBatterySnapshot(
        _ snapshot: ShiftBatterySnapshot,
        reportReference: DocumentReference,
        transaction: Transaction
    ) throws {
        try transaction.setData(
            from: FirebaseBatterySnapshotMapper.makeDTO(from: snapshot),
            forDocument: singletonDocument(
                Collection.batterySnapshot,
                reportReference: reportReference
            )
        )
    }

    nonisolated private func singletonDocument(
        _ collection: String,
        reportReference: DocumentReference
    ) -> DocumentReference {
        reportReference
            .collection(collection)
            .document(Constants.singletonDocumentID)
    }

    nonisolated private func validateWriteCount(for payload: FirebaseShiftReportWritePayload) throws {
        var writeCount = 1
        writeCount += payload.rentalOrders.count
        writeCount += 1
        writeCount += payload.souvenirSales.count
        writeCount += 1
        writeCount += payload.fines.count
        writeCount += 1
        writeCount += 1
        writeCount += 1
        writeCount += 1
        writeCount += souvenirStockAdjustmentByProductID(from: payload.souvenirSales).count
        writeCount += try batteryStockQuantityByID(
            rows: payload.report.batterySnapshot.workingRows,
            batteryItems: payload.batteryItems
        ).count

        guard writeCount <= Constants.maxTransactionWrites else {
            throw FirestoreShiftReportRepositoryError.tooManyTransactionWrites(
                writeCount: writeCount,
                limit: Constants.maxTransactionWrites
            )
        }
    }
}

nonisolated enum FirestoreShiftReportRepositoryError: LocalizedError {
    case tooManyTransactionWrites(writeCount: Int, limit: Int)
    case missingInventoryDocument(path: String)
    case invalidStockQuantity(path: String)
    case missingBatteryCatalogItem(title: String)

    var errorDescription: String? {
        switch self {
        case let .tooManyTransactionWrites(writeCount, limit):
            return "Shift report requires \(writeCount) Firestore writes, but one transaction supports \(limit)."
        case let .missingInventoryDocument(path):
            return "Не найден документ остатков Firebase: \(path)"
        case let .invalidStockQuantity(path):
            return "Некорректное поле stockQuantity в Firebase: \(path)"
        case let .missingBatteryCatalogItem(title):
            return "Не найдена батарейка в Firebase-каталоге для строки: \(title)"
        }
    }
}
