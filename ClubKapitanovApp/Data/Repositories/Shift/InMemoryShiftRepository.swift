import Foundation

/// Временная in-memory реализация `ShiftRepository`.
///
/// Хранит смены в словаре по id. Данные живут только пока работает приложение, но
/// контракт уже отражает операции будущего постоянного storage: получить открытую
/// смену, открыть, обновить операции и закрыть.
final class InMemoryShiftRepository: ShiftRepository {
    private var shiftsByID: [UUID: Shift] = [:]

    func getOpenShift(pointID: UUID) -> Shift? {
        // Важное бизнес-правило MVP: на одной точке одновременно должна быть только
        // одна открытая смена. Поэтому поиск идет по pointID и status == .open.
        shiftsByID.values.first { shift in
            shift.point.id == pointID && shift.status == .open
        }
    }

    func getShift(id: UUID) -> Shift? {
        shiftsByID[id]
    }

    func openShift(_ shift: Shift) -> Shift {
        // Повторное открытие смены на той же точке возвращает существующую открытую
        // смену, а не создает вторую. Так UI безопасен к двойному нажатию.
        if let existingShift = getOpenShift(pointID: shift.point.id) {
            return existingShift
        }

        shiftsByID[shift.id] = shift
        return shift
    }

    func updateShift(_ shift: Shift) -> Shift {
        shiftsByID[shift.id] = shift
        return shift
    }

    func closeShift(id: UUID, closedAt: Date) -> Shift? {
        // Закрытие создает новую копию Shift со status .closed и сохраняет ее обратно.
        guard let shift = shiftsByID[id] else {
            return nil
        }

        let closedShift = shift.closed(at: closedAt)
        shiftsByID[id] = closedShift
        return closedShift
    }
}
