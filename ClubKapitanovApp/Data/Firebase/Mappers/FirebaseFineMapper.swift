import Foundation

nonisolated enum FirebaseFineMapper {
    static func makeDTO(
        from fine: FineRecord,
        userNameSnapshot: String
    ) -> FirebaseFineDTO {
        FirebaseFineDTO(
            id: fine.id.uuidString,
            templateID: fine.templateID?.uuidString,
            fineNameSnapshot: fine.title,
            priceSnapshot: fine.amount.kopecks,
            createdAt: fine.createdAt,
            createdByEmployeeID: fine.createdByEmployeeID.uuidString,
            userNameSnapshot: userNameSnapshot,
            paymentMethod: fine.paymentMethod.rawValue,
            notes: fine.notes
        )
    }
}
