import Foundation
import RuuviLocal
import RuuviService
import RuuviDaemon

class RuuviDaemonCloudSyncWorker: RuuviDaemonWorker, RuuviDaemonCloudSync {
    private var localSettings: RuuviLocalSettings
    private var localSyncState: RuuviLocalSyncState
    private let cloudSyncService: RuuviServiceCloudSync
    private var needToRefreshImmediately: Bool = false

    init(
        localSettings: RuuviLocalSettings,
        localSyncState: RuuviLocalSyncState,
        cloudSyncService: RuuviServiceCloudSync
    ) {
        self.localSettings = localSettings
        self.localSyncState = localSyncState
        self.cloudSyncService = cloudSyncService
    }

    private var pullTimer: Timer?

    @objc func wakeUp() {
        if needToRefreshImmediately || needsToPullNetworkTagData {
            pullNetworkTagData()
            needToRefreshImmediately = false
        }
    }

    func refreshImmediately() {
        needToRefreshImmediately = true
        wakeUp()
    }

    func start() {
        start { [weak self] in
            guard let sSelf = self else { return }
            let timer = Timer.scheduledTimer(timeInterval: 60,
                                             target: sSelf,
                                             selector: #selector(RuuviDaemonCloudSyncWorker.wakeUp),
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
        perform(#selector(RuuviDaemonCloudSyncWorker.stopDaemon),
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
        guard let latestSyncDate = localSyncState.latestSyncDate else { return true }
        let elapsed = Int(Date().timeIntervalSince(latestSyncDate))
        return elapsed >= localSettings.networkPullIntervalSeconds
    }

    private func pullNetworkTagData() {
        cloudSyncService.syncAllRecords()
    }
}
