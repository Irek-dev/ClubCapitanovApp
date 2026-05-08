import Foundation

/// Стартовые данные для разработки без backend.
///
/// Эти фикстуры позволяют пройти основной flow приложения сразу после запуска:
/// войти по PIN, выбрать точку, открыть смену и проверить workspace. В продакшен-
/// storage такие данные должны приходить из управляемого источника каталогов и пользователей.
enum InMemoryFixtures {
    static let blackLakePoint = Point(
        name: "Черное Озеро",
        city: "Казань",
        address: "Черное Озеро"
    )

    static let gorkyParkPoint = Point(
        name: "Парк Горького",
        city: "Москва",
        address: "Парк Горького"
    )

    static let megaPoint = Point(
        name: "МЕГА",
        city: "Казань",
        address: "МЕГА"
    )

    static let points: [Point] = [
        blackLakePoint,
        gorkyParkPoint,
        megaPoint
    ]

    static let users: [User] = [
        User(pinCode: "1111", firstName: "Ирек", lastName: "Шакиров", role: .staff),
        User(pinCode: "2222", firstName: "Амир", lastName: "Ибрагимов", role: .staff),
        User(
            pinCode: "3333",
            firstName: "Марина",
            lastName: "Управляева",
            role: .manager,
            managedPointID: blackLakePoint.id
        )
    ]
}
