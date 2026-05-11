import Foundation

nonisolated enum FirebaseEquipmentSnapshotMapper {
    static func makeDTO(from snapshot: ShiftEquipmentSnapshot) -> FirebaseEquipmentSnapshotDTO {
        FirebaseEquipmentSnapshotDTO(
            workingRows: snapshot.workingRows.map(makeRowDTO),
            discardedRows: snapshot.discardedRows.map(makeRowDTO),
            notes: snapshot.notes
        )
    }

    private static func makeRowDTO(
        from row: ShiftEquipmentCountRow
    ) -> FirebaseEquipmentSnapshotDTO.Row {
        FirebaseEquipmentSnapshotDTO.Row(
            equipmentNameSnapshot: row.title,
            count: row.count
        )
    }
}
