import Foundation

class PullRuuviNetworkDaemonOperation: BackgroundWorker, PullRuuviNetworkDaemon {

    var settings: Settings!
    var ruuviTagNetworkOperationsManager: RuuviNetworkTagOperationsManager!

    @UserDefault("PullRuuviNetworkDaemonOperation.ruuviNetworkTagLastPullDate", defaultValue: Date())
    private var lastPullDate: Date
    private var pullTimer: Timer?

    @objc func wakeUp() {
        if needsToPullNetworkTagData {
            pullNetworkTagData()
            lastPullDate = Date()
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
        }
    }

    func stop() {
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
        let elapsed = Int(Date().timeIntervalSince(lastPullDate))
        return elapsed > settings.networkPullIntervalMinutes * 60
    }

    private func pullNetworkTagData() {
    }
}
