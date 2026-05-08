import Foundation

/// Итоговый snapshot смены на момент закрытия.
///
/// Отчет должен быть неизменяемой исторической записью: он сохраняет итоговые суммы,
/// разбивки и ручные поля, чтобы через годы не пересчитываться по изменившимся
/// каталогам, пользователям или правилам.
struct ShiftCloseReport: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let shiftID: UUID
    let pointID: UUID
    let shiftDate: Date
    let createdAt: Date
    let createdByUserID: UUID
    let weatherNote: String?
    let totalRevenue: Money
    let rentalSummary: ShiftRentalCloseSummary
    let finesSummary: ShiftFinesCloseSummary
    let souvenirSummary: ShiftSouvenirCloseSummary
    let payrollSummary: ShiftPayrollCloseSummary?
    let equipmentSnapshot: ShiftEquipmentSnapshot
    let batterySnapshot: ShiftBatterySnapshot
    let notes: String?

    init(
        id: UUID = UUID(),
        shiftID: UUID,
        pointID: UUID,
        shiftDate: Date,
        createdAt: Date,
        createdByUserID: UUID,
        weatherNote: String? = nil,
        totalRevenue: Money,
        rentalSummary: ShiftRentalCloseSummary,
        finesSummary: ShiftFinesCloseSummary,
        souvenirSummary: ShiftSouvenirCloseSummary,
        payrollSummary: ShiftPayrollCloseSummary? = nil,
        equipmentSnapshot: ShiftEquipmentSnapshot,
        batterySnapshot: ShiftBatterySnapshot,
        notes: String? = nil
    ) {
        self.id = id
        self.shiftID = shiftID
        self.pointID = pointID
        self.shiftDate = shiftDate
        self.createdAt = createdAt
        self.createdByUserID = createdByUserID
        self.weatherNote = weatherNote
        self.totalRevenue = totalRevenue
        self.rentalSummary = rentalSummary
        self.finesSummary = finesSummary
        self.souvenirSummary = souvenirSummary
        self.payrollSummary = payrollSummary
        self.equipmentSnapshot = equipmentSnapshot
        self.batterySnapshot = batterySnapshot
        self.notes = notes
    }
}

struct ShiftRentalCloseSummary: Hashable, Codable, Sendable {
    /// Автоматическая сводка проката: количество сдач, выручка, типы и оплаты.
    let totalTripsCount: Int
    let revenue: Money
    let tripsByType: [ShiftRentalTypeCountRow]
    let tariffBreakdown: [ShiftTariffBreakdownRow]
    let payments: [ShiftPaymentBreakdownRow]
    let chipRevenue: Money?
}

struct ShiftFinesCloseSummary: Hashable, Codable, Sendable {
    /// Автоматическая сводка начисленных штрафов за смену.
    let totalCount: Int
    let totalAmount: Money
    let rows: [ShiftFineBreakdownRow]
}

struct ShiftSouvenirCloseSummary: Hashable, Codable, Sendable {
    /// Автоматическая сводка продаж сувенирки за смену.
    let totalRevenue: Money
    let rows: [ShiftSouvenirBreakdownRow]
}

struct ShiftPayrollCloseSummary: Hashable, Codable, Sendable {
    /// Snapshot выплат сотрудникам по правилам зарплаты конкретной смены.
    let ratePerTrip: Money
    let totalTripsCount: Int
    let totalFund: Money
    let totalAmount: Money
    let rows: [ShiftPayrollRow]
}

struct ShiftEquipmentSnapshot: Hashable, Codable, Sendable {
    /// Ручной блок закрытия смены по состоянию оборудования.
    let workingRows: [ShiftEquipmentCountRow]
    let discardedRows: [ShiftEquipmentCountRow]
    let notes: String?

    static let empty = ShiftEquipmentSnapshot(
        workingRows: [],
        discardedRows: [],
        notes: nil
    )
}

struct ShiftBatterySnapshot: Hashable, Codable, Sendable {
    /// Ручной блок закрытия смены по рабочим и списанным батарейкам.
    let workingTotal: Int?
    let workingRows: [ShiftBatteryCountRow]
    let discardedRows: [ShiftBatteryCountRow]
    let notes: String?

    static let empty = ShiftBatterySnapshot(
        workingTotal: nil,
        workingRows: [],
        discardedRows: [],
        notes: nil
    )
}

struct ShiftRentalTypeCountRow: Hashable, Codable, Sendable {
    let title: String
    let count: Int
}

struct ShiftTariffBreakdownRow: Hashable, Codable, Sendable {
    let title: String
    let amount: Money
}

struct ShiftPaymentBreakdownRow: Hashable, Codable, Sendable {
    let paymentMethod: PaymentMethod
    let amount: Money
}

struct ShiftFineBreakdownRow: Hashable, Codable, Sendable {
    let title: String
    let count: Int
    let amount: Money
}

struct ShiftSouvenirBreakdownRow: Hashable, Codable, Sendable {
    let title: String
    let count: Int
    let amount: Money
}

struct ShiftPayrollRow: Hashable, Codable, Sendable {
    let participantID: UUID
    let employeeID: UUID
    let employeeName: String
    let roleSnapshot: UserRole
    let joinedAt: Date
    let leftAt: Date?
    let paidUntilAt: Date
    let workedDurationSeconds: TimeInterval
    let participatedTripsCount: Int
    let amount: Money
}

struct ShiftEquipmentCountRow: Hashable, Codable, Sendable {
    let title: String
    let count: Int
}

struct ShiftBatteryCountRow: Hashable, Codable, Sendable {
    let title: String
    let count: Int
}
