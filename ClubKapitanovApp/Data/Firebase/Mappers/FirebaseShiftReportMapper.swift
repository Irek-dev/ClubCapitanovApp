import Foundation

nonisolated enum FirebaseShiftReportMapper {
    static func makeDTO(
        from report: ShiftCloseReport,
        reportID: String? = nil,
        reportNumber: String? = nil,
        pointNameSnapshot: String,
        userNameSnapshot: String,
        paymentRevenue: [FirebaseShiftReportDTO.PaymentRevenue]? = nil,
        inventoryAppliedAt: Date? = nil,
        textReport: String? = nil
    ) -> FirebaseShiftReportDTO {
        FirebaseShiftReportDTO(
            id: reportID ?? report.id.uuidString,
            reportNumber: reportNumber ?? reportID ?? report.id.uuidString,
            shiftID: report.shiftID.uuidString,
            pointID: report.pointID.uuidString,
            pointNameSnapshot: pointNameSnapshot,
            shiftDate: report.shiftDate,
            createdAt: report.createdAt,
            createdByUserID: report.createdByUserID.uuidString,
            userNameSnapshot: userNameSnapshot,
            weatherNote: report.weatherNote,
            totalRevenueKopecks: report.totalRevenue.kopecks,
            rentalRevenueKopecks: report.rentalSummary.revenue.kopecks,
            souvenirRevenueKopecks: report.souvenirSummary.totalRevenue.kopecks,
            finesRevenueKopecks: report.finesSummary.totalAmount.kopecks,
            payrollTotalKopecks: report.payrollSummary?.totalAmount.kopecks,
            paymentRevenue: paymentRevenue ?? report.rentalSummary.payments.map {
                FirebaseShiftReportDTO.PaymentRevenue(
                    paymentMethod: $0.paymentMethod.rawValue,
                    amountKopecks: $0.amount.kopecks
                )
            },
            rentalTripsCount: report.rentalSummary.totalTripsCount,
            souvenirItemsCount: report.souvenirSummary.rows.reduce(0) { $0 + $1.count },
            finesCount: report.finesSummary.totalCount,
            equipmentNotes: report.equipmentSnapshot.notes,
            batteryNotes: report.batterySnapshot.notes,
            notes: report.notes,
            textReport: textReport,
            inventoryAppliedAt: inventoryAppliedAt
        )
    }
}
