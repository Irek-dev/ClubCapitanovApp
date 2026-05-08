import Foundation

/// Временная in-memory реализация `ReportRepository`.
///
/// Отчеты закрытия смены хранятся отдельно от `Shift`, чтобы постоянный storage мог
/// сохранять неизменяемые snapshots без разрастания `ShiftRepository`.
final class InMemoryReportRepository: ReportRepository {
    private var closeReportsByShiftID: [UUID: ShiftCloseReport] = [:]

    func getCloseReport(shiftID: UUID) -> ShiftCloseReport? {
        closeReportsByShiftID[shiftID]
    }

    func saveCloseReport(_ report: ShiftCloseReport) {
        closeReportsByShiftID[report.shiftID] = report
    }
}
