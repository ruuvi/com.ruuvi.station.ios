import Foundation
import RuuviLocal

class PullWebDaemonOperations: BackgroundWorker, PullWebDaemon {
    var settings: RuuviLocalSettings!
    var webTagOperationsManager: WebTagOperationsManager!

    @UserDefault("PullWebDaemonOperations.webTagLastPullDate", defaultValue: Date())
    private var webTagLastPullDate: Date
    private var pullTimer: Timer?

    @objc func wakeUp() {
        if needsToPullWebTagData() {
            pullWebTagData()
            webTagLastPullDate = Date()
        }
    }

    func start() {
        start { [weak self] in
            guard let sSelf = self else { return }
            let timer = Timer.scheduledTimer(timeInterval: 60,
                                             target: sSelf,
                                             selector: #selector(PullWebDaemonOperations.wakeUp),
                                             userInfo: nil,
                                             repeats: true)
            RunLoop.current.add(timer, forMode: .common)
            sSelf.pullTimer = timer
        }
    }

    func stop() {
        perform(#selector(PullWebDaemonOperations.stopDaemon),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
    }

    @objc private func stopDaemon() {
        pullTimer?.invalidate()
        stopWork()
    }

    private func needsToPullWebTagData() -> Bool {
        let elapsed = Int(Date().timeIntervalSince(webTagLastPullDate))
        return elapsed > settings.webPullIntervalMinutes * 60
    }

    private func pullWebTagData() {
        webTagOperationsManager.alertsPullOperations()
            .on(success: { operations in
                let queue = OperationQueue()
                queue.maxConcurrentOperationCount = 1
                queue.addOperations(operations, waitUntilFinished: false)
            })
    }

}
