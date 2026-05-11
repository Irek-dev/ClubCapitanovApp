import Foundation

nonisolated enum FirebaseBatterySnapshotMapper {
    static func makeDTO(from snapshot: ShiftBatterySnapshot) -> FirebaseBatterySnapshotDTO {
        FirebaseBatterySnapshotDTO(
            workingTotal: snapshot.workingTotal,
            workingRows: snapshot.workingRows.map(makeRowDTO),
            discardedRows: snapshot.discardedRows.map(makeRowDTO),
            notes: snapshot.notes
        )
    }

    private static func makeRowDTO(
        from row: ShiftBatteryCountRow
    ) -> FirebaseBatterySnapshotDTO.Row {
        FirebaseBatterySnapshotDTO.Row(
            batteryNameSnapshot: row.title,
            count: row.count
        )
    }
}
