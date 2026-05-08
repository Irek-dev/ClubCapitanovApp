import Foundation

/// Считает зарплатный фонд смены по фактическому времени завершения прокатов.
///
/// Каждый завершенный объект проката добавляет 50 рублей в общий фонд. Сумма конкретной
/// сдачи делится только между участниками, которые были в смене на момент
/// `RentalOrder.finishedAt`. В отчете сохраняются интервалы участия и начисления,
/// чтобы исторически было видно, за какой период сотруднику начислена выплата.
struct BuildShiftPayrollSummaryUseCase {
    private enum Constants {
        static let ratePerCompletedTrip = Money(kopecks: 5_000)
    }

    func execute(shift: Shift, closedAt: Date) -> ShiftPayrollCloseSummary? {
        guard !shift.participants.isEmpty else {
            return nil
        }

        let completedOrders = shift.rentalOrders
            .filter { $0.status == .completed }
            .sorted { ($0.finishedAt ?? $0.startedAt) < ($1.finishedAt ?? $1.startedAt) }
        let totalTripsCount = completedOrders.reduce(0) { $0 + $1.quantity }
        let totalFund = Constants.ratePerCompletedTrip.multiplied(by: totalTripsCount)
        var amountsByParticipantID: [UUID: Money] = [:]
        var participatedTripsByParticipantID: [UUID: Int] = [:]

        shift.participants.forEach { participant in
            amountsByParticipantID[participant.id] = .zero
            participatedTripsByParticipantID[participant.id] = 0
        }

        completedOrders.forEach { order in
            guard let finishedAt = order.finishedAt, order.quantity > 0 else {
                return
            }

            let activeParticipants = participantsActive(
                at: finishedAt,
                in: shift.participants,
                closedAt: closedAt
            )

            guard !activeParticipants.isEmpty else {
                return
            }

            activeParticipants.forEach { participant in
                participatedTripsByParticipantID[participant.id, default: 0] += order.quantity
            }

            distribute(
                amount: Constants.ratePerCompletedTrip.multiplied(by: order.quantity),
                between: activeParticipants,
                amountsByParticipantID: &amountsByParticipantID
            )
        }

        let rows = shift.participants
            .sorted { lhs, rhs in
                if lhs.joinedAt != rhs.joinedAt {
                    return lhs.joinedAt < rhs.joinedAt
                }
                return lhs.displayNameSnapshot < rhs.displayNameSnapshot
            }
            .map { participant in
                let paidUntilAt = effectiveEndDate(for: participant, closedAt: closedAt)
                return ShiftPayrollRow(
                    participantID: participant.id,
                    employeeID: participant.userID,
                    employeeName: participant.displayNameSnapshot,
                    roleSnapshot: participant.roleSnapshot,
                    joinedAt: participant.joinedAt,
                    leftAt: participant.leftAt,
                    paidUntilAt: paidUntilAt,
                    workedDurationSeconds: max(0, paidUntilAt.timeIntervalSince(participant.joinedAt)),
                    participatedTripsCount: participatedTripsByParticipantID[participant.id] ?? 0,
                    amount: amountsByParticipantID[participant.id] ?? .zero
                )
            }

        return ShiftPayrollCloseSummary(
            ratePerTrip: Constants.ratePerCompletedTrip,
            totalTripsCount: totalTripsCount,
            totalFund: totalFund,
            totalAmount: Money.sum(rows.map(\.amount)),
            rows: rows
        )
    }

    private func participantsActive(
        at date: Date,
        in participants: [ShiftParticipant],
        closedAt: Date
    ) -> [ShiftParticipant] {
        participants
            .filter { participant in
                participant.joinedAt <= date && date <= effectiveEndDate(for: participant, closedAt: closedAt)
            }
            .sorted { lhs, rhs in
                if lhs.joinedAt != rhs.joinedAt {
                    return lhs.joinedAt < rhs.joinedAt
                }
                return lhs.displayNameSnapshot < rhs.displayNameSnapshot
            }
    }

    private func distribute(
        amount: Money,
        between participants: [ShiftParticipant],
        amountsByParticipantID: inout [UUID: Money]
    ) {
        guard !participants.isEmpty else {
            return
        }

        let baseShare = amount.kopecks / participants.count
        let remainder = amount.kopecks % participants.count

        participants.enumerated().forEach { index, participant in
            let extraKopeck = index < remainder ? 1 : 0
            amountsByParticipantID[participant.id, default: .zero] += Money(
                kopecks: baseShare + extraKopeck
            )
        }
    }

    private func effectiveEndDate(for participant: ShiftParticipant, closedAt: Date) -> Date {
        guard let leftAt = participant.leftAt else {
            return closedAt
        }

        return min(leftAt, closedAt)
    }
}
