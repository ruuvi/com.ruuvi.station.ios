import Foundation
import BTKit

class RuuviTagConnectionDaemonBTKit: BackgroundWorker, RuuviTagConnectionDaemon {
    
    var foreground: BTForeground!
    var background: BTBackground!
    var ruuviTagPersistence: RuuviTagPersistence!
    var settings: Settings!
    var connectionPersistence: ConnectionPersistence!
    var gattService: GATTService!
    
    private var scanToken: ObservationToken?
    private var isOnToken: NSObjectProtocol?
    private var syncInterval: TimeInterval {
        return TimeInterval(settings.connectionDaemonIntervalMinutes * 60)
    }
    
    @objc private class RuuviTagConnectableDaemonWrapper: NSObject {
        var device: RuuviTag
        
        init(device: RuuviTag) {
            self.device = device
        }
    }
    
    deinit {
        scanToken?.invalidate()
        if let isOnToken = isOnToken {
            NotificationCenter.default.removeObserver(isOnToken)
        }
    }
    
    override init() {
        super.init()
        isOnToken = NotificationCenter.default.addObserver(forName: .isConnectionDaemonOnDidChange, object: nil, queue: .main) { [weak self] _ in
            guard let sSelf = self else { return }
            if sSelf.settings.isConnectionDaemonOn {
                sSelf.start()
            } else {
                sSelf.stop()
            }
        }
    }
    
    func start() {
        start { [weak self] in
            guard let sSelf = self else { return }
            sSelf.scanToken = sSelf.foreground.scan(sSelf, options: [.callbackQueue(.untouch)]) { (observer, device) in
                if let ruuviTag = device.ruuvi?.tag, ruuviTag.isConnectable {
                    sSelf.perform(#selector(RuuviTagConnectionDaemonBTKit.onDidReceiveConnectableTagAdvertisement(ruuviTagWrapped:)),
                    on: sSelf.thread,
                    with: RuuviTagConnectableDaemonWrapper(device: ruuviTag),
                    waitUntilDone: false,
                    modes: [RunLoop.Mode.default.rawValue])
                }
            }
        }
    }
    
    func stop() {
        perform(#selector(RuuviTagConnectionDaemonBTKit.stopDaemon),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
    }

    @objc private func stopDaemon() {
        scanToken?.invalidate()
        stopWork()
    }
    
    @objc private func onDidReceiveConnectableTagAdvertisement(ruuviTagWrapped: RuuviTagConnectableDaemonWrapper) {
        let device = ruuviTagWrapped.device
        let operationIsAlreadyInQueue = gattService.isSyncingLogs(with: device.uuid)
        let logSyncDate = connectionPersistence.logSyncDate(uuid: device.uuid)
        if !operationIsAlreadyInQueue, !device.isConnected, needsToConnectAndLoadData(for: logSyncDate) {
            gattService.syncLogs(with: device.uuid)
        }
    }
    
    private func needsToConnectAndLoadData(for logSyncDate: Date?) -> Bool {
        if let logSyncDate = logSyncDate {
            return Date().timeIntervalSince(logSyncDate) > syncInterval
        } else {
            return true
        }
    }
    
}
