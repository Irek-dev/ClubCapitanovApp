import Foundation

nonisolated enum FirebaseSouvenirSaleMapper {
    static func makeDTO(
        from sale: SouvenirSale,
        userNameSnapshot: String
    ) -> FirebaseSouvenirSaleDTO {
        FirebaseSouvenirSaleDTO(
            id: sale.id.uuidString,
            productID: sale.productID?.uuidString,
            souvenirNameSnapshot: sale.itemName,
            quantity: sale.quantity,
            priceSnapshot: sale.unitPrice.kopecks,
            totalPriceKopecks: sale.totalPrice.kopecks,
            soldAt: sale.soldAt,
            soldByEmployeeID: sale.soldByEmployeeID.uuidString,
            userNameSnapshot: userNameSnapshot,
            paymentMethod: sale.paymentMethod.rawValue,
            notes: sale.notes
        )
    }
}
