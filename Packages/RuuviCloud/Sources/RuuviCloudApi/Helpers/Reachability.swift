import Network

enum Reachability {
    private static let monitor = NWPathMonitor()

    static var active = false
    static var expensive = false

    /// Monitors internet connectivity changes. Updates with every change in connectivity.
    /// Updates variables for availability and if it's expensive (cellular).
    static func start() {
        guard monitor.pathUpdateHandler == nil else { return }

        monitor.pathUpdateHandler = { update in
            active = update.status == .satisfied ? true : false
            expensive = update.isExpensive ? true : false
        }

        monitor.start(queue: DispatchQueue(label: "InternetMonitor"))
    }
}
