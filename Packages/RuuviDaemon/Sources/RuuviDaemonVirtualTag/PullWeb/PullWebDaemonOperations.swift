import Foundation
import RuuviLocal
import RuuviDaemon

public final class PullWebDaemonOperations: RuuviDaemonWorker, PullWebDaemon {
    private let settings: RuuviLocalSettings
    private let webTagOperationsManager: WebTagOperationsManager

    public init(
        settings: RuuviLocalSettings,
        webTagOperationsManager: WebTagOperationsManager
    ) {
        self.settings = settings
        self.webTagOperationsManager = webTagOperationsManager
    }

    @UserDefault("PullWebDaemonOperations.webTagLastPullDate", defaultValue: Date())
    private var webTagLastPullDate: Date
    private var pullTimer: Timer?

    @objc public func wakeUp() {
        if needsToPullWebTagData() {
            pullWebTagData()
            webTagLastPullDate = Date()
        }
    }

    public func start() {
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

    public func stop() {
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
