import Foundation
import Network

final class NetworkManager: ObservableObject {
    let monitor = NWPathMonitor()
    let queue = DispatchQueue(label: "NetworkManager")
    @Published var isConnected: Bool = false

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}
