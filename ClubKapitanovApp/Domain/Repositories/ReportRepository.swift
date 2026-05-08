import Foundation

/// Абстракция хранения итогового отчета закрытия смены.
///
/// Отчет отделен от самой смены: смена хранит операции, а close report фиксирует
/// неизменяемый snapshot итогов и ручных полей на момент закрытия.
protocol ReportRepository {
    func getCloseReport(shiftID: UUID) -> ShiftCloseReport?
    func saveCloseReport(_ report: ShiftCloseReport)
}
