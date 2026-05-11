import Foundation

nonisolated protocol FirebaseShiftReportWriting {
    func saveShiftReport(_ report: ShiftCloseReport) async throws
    func saveShiftReport(_ payload: FirebaseShiftReportWritePayload) async throws
}
