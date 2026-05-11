import Foundation

nonisolated enum FirebaseRentalOrderMapper {
    static func makeDTO(from order: RentalOrder) -> FirebaseRentalOrderDTO {
        FirebaseRentalOrderDTO(
            id: order.id.uuidString,
            rentalTypeID: order.rentalTypeID.uuidString,
            rentalTypeNameSnapshot: order.rentalTypeNameSnapshot,
            rentedAssetIDs: order.rentedAssetIDs.map(\.uuidString),
            rentedAssetNumbersSnapshot: order.rentedAssetNumbersSnapshot,
            rentedItemsSnapshot: order.rentedItemsSnapshot.map(makeItemSnapshotDTO),
            createdAt: order.createdAt,
            startedAt: order.startedAt,
            expectedEndAt: order.expectedEndAt,
            finishedAt: order.finishedAt,
            canceledAt: order.canceledAt,
            durationMinutes: order.durationMinutes,
            quantity: quantity(from: order),
            rentalPeriodsCount: order.rentalPeriodsCount,
            billableTripsCount: billableTripsCount(from: order),
            priceSnapshot: order.totalPrice.kopecks,
            payrollSnapshot: makePayrollSnapshot(from: order),
            paymentMethod: order.paymentMethod.rawValue,
            status: order.status.rawValue,
            notes: order.notes
        )
    }

    private static func makeItemSnapshotDTO(
        from item: RentalOrderItemSnapshot
    ) -> FirebaseRentalOrderDTO.ItemSnapshot {
        FirebaseRentalOrderDTO.ItemSnapshot(
            rentalTypeID: item.rentalTypeID.uuidString,
            rentalTypeNameSnapshot: item.rentalTypeNameSnapshot,
            rentalTypeCodeSnapshot: item.rentalTypeCodeSnapshot,
            displayNumber: item.displayNumber,
            rentalTariffID: item.rentalTariffID?.uuidString,
            tariffTitleSnapshot: item.tariffTitleSnapshot,
            tariffDurationMinutes: item.tariffDurationMinutes,
            priceSnapshot: item.tariffPriceSnapshot?.kopecks,
            payrollSnapshot: item.payrollRateSnapshot?.kopecks
        )
    }

    private static func makePayrollSnapshot(from order: RentalOrder) -> Int? {
        let rates = order.rentedItemsSnapshot.compactMap(\.payrollRateSnapshot)
        guard !rates.isEmpty else {
            return nil
        }

        return rates.reduce(0) { $0 + $1.kopecks } * order.rentalPeriodsCount
    }

    private static func quantity(from order: RentalOrder) -> Int {
        if !order.rentedItemsSnapshot.isEmpty {
            return order.rentedItemsSnapshot.count
        }

        return order.rentedAssetNumbersSnapshot.count
    }

    private static func billableTripsCount(from order: RentalOrder) -> Int {
        quantity(from: order) * order.rentalPeriodsCount
    }
}
