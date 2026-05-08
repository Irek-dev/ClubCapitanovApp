import Foundation

/// Центральная сущность рабочего дня на точке.
///
/// Смена объединяет точку, host-iPad, участников, подключения и все операции.
/// Сейчас она хранится in-memory, но структура не привязана к конкретному storage.
struct Shift: Identifiable, Hashable, Codable, Sendable {
    /// Уникальный идентификатор смены.
    let id: UUID
    /// Точка, на которой открыта смена.
    let point: Point
    /// Пользователь, открывший смену.
    let openedByUserID: UUID
    /// Общее устройство точки, на котором смена была изначально открыта.
    let hostDevice: WorkDevice
    /// Дата и время открытия смены.
    let openedAt: Date
    /// Дата и время закрытия смены, если смена уже завершена.
    let closedAt: Date?
    /// Текущее состояние смены.
    let status: ShiftStatus
    /// Сотрудники, работающие в рамках этой смены.
    let participants: [ShiftParticipant]
    /// Подключения пользователей и устройств к текущей смене.
    let connections: [ShiftConnection]
    /// Все заказы аренды, оформленные в рамках смены.
    let rentalOrders: [RentalOrder]
    /// Все продажи сувениров, проведенные в рамках смены.
    let souvenirSales: [SouvenirSale]
    /// Все штрафы, зафиксированные в рамках смены.
    let fines: [FineRecord]
    /// Общая заметка по смене.
    let notes: String?

    init(
        id: UUID = UUID(),
        point: Point,
        openedByUserID: UUID,
        hostDevice: WorkDevice,
        openedAt: Date,
        closedAt: Date? = nil,
        status: ShiftStatus,
        participants: [ShiftParticipant] = [],
        connections: [ShiftConnection] = [],
        rentalOrders: [RentalOrder] = [],
        souvenirSales: [SouvenirSale] = [],
        fines: [FineRecord] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.point = point
        self.openedByUserID = openedByUserID
        self.hostDevice = hostDevice
        self.openedAt = openedAt
        self.closedAt = closedAt
        self.status = status
        self.participants = participants
        self.connections = connections
        self.rentalOrders = rentalOrders
        self.souvenirSales = souvenirSales
        self.fines = fines
        self.notes = notes
    }

    func replacingOperations(
        rentalOrders: [RentalOrder]? = nil,
        souvenirSales: [SouvenirSale]? = nil,
        fines: [FineRecord]? = nil
    ) -> Shift {
        // Сущность immutable, поэтому любые изменения операций возвращают новую копию.
        // Такой подход проще тестировать и безопаснее для будущего persistence-слоя.
        Shift(
            id: id,
            point: point,
            openedByUserID: openedByUserID,
            hostDevice: hostDevice,
            openedAt: openedAt,
            closedAt: closedAt,
            status: status,
            participants: participants,
            connections: connections,
            rentalOrders: rentalOrders ?? self.rentalOrders,
            souvenirSales: souvenirSales ?? self.souvenirSales,
            fines: fines ?? self.fines,
            notes: notes
        )
    }

    func replacingParticipants(_ participants: [ShiftParticipant]) -> Shift {
        // Участники — часть исторического контекста смены, поэтому обновляем их
        // через новую immutable-копию так же, как операции и статус.
        Shift(
            id: id,
            point: point,
            openedByUserID: openedByUserID,
            hostDevice: hostDevice,
            openedAt: openedAt,
            closedAt: closedAt,
            status: status,
            participants: participants,
            connections: connections,
            rentalOrders: rentalOrders,
            souvenirSales: souvenirSales,
            fines: fines,
            notes: notes
        )
    }

    func closed(at closedAt: Date) -> Shift {
        // Закрытие смены не удаляет операции, участников или подключения: закрытая
        // смена должна полностью сохранять исторический контекст.
        Shift(
            id: id,
            point: point,
            openedByUserID: openedByUserID,
            hostDevice: hostDevice,
            openedAt: openedAt,
            closedAt: closedAt,
            status: .closed,
            participants: participants,
            connections: connections,
            rentalOrders: rentalOrders,
            souvenirSales: souvenirSales,
            fines: fines,
            notes: notes
        )
    }
}
