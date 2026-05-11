import Foundation

nonisolated struct FirebaseShiftReportWritePayload: Sendable {
    let reportID: String
    let report: ShiftCloseReport
    let rentalOrders: [RentalOrder]
    let souvenirSales: [SouvenirSale]
    let fines: [FineRecord]
    let batteryItems: [BatteryItem]
    let pointNameSnapshot: String
    let createdByUserNameSnapshot: String
    let userNameSnapshotsByUserID: [UUID: String]
    let reportNumber: String
    let textReport: String?

    init(
        reportID: String? = nil,
        report: ShiftCloseReport,
        rentalOrders: [RentalOrder] = [],
        souvenirSales: [SouvenirSale] = [],
        fines: [FineRecord] = [],
        batteryItems: [BatteryItem] = [],
        pointNameSnapshot: String? = nil,
        createdByUserNameSnapshot: String? = nil,
        userNameSnapshotsByUserID: [UUID: String] = [:],
        reportNumber: String? = nil,
        textReport: String? = nil
    ) {
        let resolvedReportNumber = reportNumber ?? Self.stableReportNumber(
            shiftID: report.shiftID,
            shiftDate: report.shiftDate
        )
        self.reportID = reportID ?? resolvedReportNumber
        self.report = report
        self.rentalOrders = rentalOrders
        self.souvenirSales = souvenirSales
        self.fines = fines
        self.batteryItems = batteryItems
        self.pointNameSnapshot = pointNameSnapshot ?? report.pointID.uuidString
        self.createdByUserNameSnapshot = createdByUserNameSnapshot ?? report.createdByUserID.uuidString
        self.userNameSnapshotsByUserID = userNameSnapshotsByUserID
        self.reportNumber = resolvedReportNumber
        self.textReport = textReport
    }

    func userNameSnapshot(for userID: UUID) -> String {
        userNameSnapshotsByUserID[userID] ?? userID.uuidString
    }

    static func stableReportID(shiftID: UUID, shiftDate: Date) -> String {
        stableReportNumber(shiftID: shiftID, shiftDate: shiftDate)
    }

    static func stableReportNumber(shiftID: UUID, shiftDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmm"

        return "report_\(formatter.string(from: shiftDate))_\(shiftID.uuidString.prefix(8))"
    }
}
