import Foundation
import Network

/// Легкая проверка сетевого состояния для действий, которые нельзя ставить
/// в offline-очередь и выполнять позже без явного подтверждения пользователя.
protocol ConnectivityChecking: AnyObject {
    var hasInternetConnection: Bool { get }
}

final class NetworkConnectivityService: ConnectivityChecking {
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "clubkapitanov.network-connectivity")
    private var latestStatus: NWPath.Status

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        self.latestStatus = monitor.currentPath.status

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.latestStatus = path.status
            }
        }
        monitor.start(queue: queue)
    }

    var hasInternetConnection: Bool {
        latestStatus == .satisfied || monitor.currentPath.status == .satisfied
    }

    deinit {
        monitor.cancel()
    }
}
