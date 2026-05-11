# Firebase report writes

## GoogleService-Info.plist

1. Open Firebase Console and create or select the iOS app with the app bundle id.
2. Download `GoogleService-Info.plist`.
3. Add the file to the `ClubKapitanovApp` app target in Xcode.
4. Keep the file named exactly `GoogleService-Info.plist`.

`AppDelegate` already calls `FirebaseApp.configure()` during app startup.

## What is written

`FirestoreShiftReportRepository` writes the root document:

- `shiftReports/{reportId}`

The close-shift report id is stable and readable:

- `report_yyyy-MM-dd_HHmm_XXXXXXXX`

The same value is also written to `reportNumber`.

It also writes report subcollections:

- `shiftReports/{reportId}/rentalOrders/{rentalOrderId}`
- `shiftReports/{reportId}/rentalSummary/current`
- `shiftReports/{reportId}/souvenirSales/{saleId}`
- `shiftReports/{reportId}/souvenirSummary/current`
- `shiftReports/{reportId}/fines/{fineId}`
- `shiftReports/{reportId}/fineSummary/current`
- `shiftReports/{reportId}/payroll/current`
- `shiftReports/{reportId}/equipmentSnapshot/current`
- `shiftReports/{reportId}/batterySnapshot/current`

In the same Firestore transaction it applies inventory updates for the point:

- decrements `points/{pointId}/souvenirs/{souvenirId}.stockQuantity` by sold quantity
- sets `points/{pointId}/batteryTypes/{batteryId}.stockQuantity` from the close-shift battery snapshot

`saveShiftReport(_ report: ShiftCloseReport)` saves the report document and summary/snapshot documents that are present in `ShiftCloseReport`. To write operation documents too, call `saveShiftReport(_ payload: FirebaseShiftReportWritePayload)` and pass rental orders, souvenir sales, fines, and human-readable snapshot names.

## How to verify

1. Run a build with Firebase configured.
2. Close a real shift from the app flow when it is safe to create a report in the current Firebase project.
3. Open Firebase Console -> Firestore Database.
4. Check the `shiftReports` collection.
5. Open the saved report document and verify the subcollections listed above.
