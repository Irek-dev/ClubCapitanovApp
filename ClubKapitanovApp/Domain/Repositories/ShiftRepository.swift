import Foundation

/// Абстракция хранения смен.
///
/// Правило "на точке может быть только одна открытая смена" реализуется в Data-слое,
/// а Feature-слой работает с этим через простой контракт открытия/обновления/закрытия.
protocol ShiftRepository {
    func getOpenShift(pointID: UUID) -> Shift?
    func getShift(id: UUID) -> Shift?
    func openShift(_ shift: Shift) -> Shift
    func updateShift(_ shift: Shift) -> Shift
    func closeShift(id: UUID, closedAt: Date) -> Shift?
}
