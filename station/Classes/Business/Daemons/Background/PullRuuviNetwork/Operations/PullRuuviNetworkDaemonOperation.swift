import Foundation

class PullRuuviNetworkDaemonOperation: BackgroundWorker, PullRuuviNetworkDaemon {

    var settings: Settings!
    var ruuviTagNetworkOperationsManager: RuuviNetworkTagOperationsManager!
    var networkPersistance: NetworkPersistence!
    var needToRefreshImmediately: Bool = false

    private var pullTimer: Timer?

    @objc func wakeUp() {
        if needToRefreshImmediately || needsToPullNetworkTagData {
            pullNetworkTagData()
            networkPersistance.lastSyncDate = Date()
            needToRefreshImmediately = false
        }
    }

    func start() {
        start { [weak self] in
            guard let sSelf = self else { return }
            let timer = Timer.scheduledTimer(timeInterval: 60,
                                             target: sSelf,
                                             selector: #selector(PullRuuviNetworkDaemonOperation.wakeUp),
                                             userInfo: nil,
                                             repeats: true)
            RunLoop.current.add(timer, forMode: .common)
            sSelf.pullTimer = timer
            sSelf.needToRefreshImmediately = false
        }
    }

    func stop() {
        needToRefreshImmediately = true
        guard let thread = thread else {
            return
        }
        perform(#selector(PullRuuviNetworkDaemonOperation.stopDaemon),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
    }

    @objc private func stopDaemon() {
        pullTimer?.invalidate()
        stopWork()
    }

    private var needsToPullNetworkTagData: Bool {
        guard let lastPullDate = networkPersistance.lastSyncDate else {
            return true
        }
        let elapsed = Int(Date().timeIntervalSince(lastPullDate))
        return elapsed >= settings.networkPullIntervalSeconds
    }

    private func pullNetworkTagData() {
        ruuviTagNetworkOperationsManager.pullNetworkTagOperations().on { (operations) in
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            queue.addOperations(operations, waitUntilFinished: false)
        }
    }
}
