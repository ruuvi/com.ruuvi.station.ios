import Foundation
import RealmSwift
import BTKit

class RuuviTagConnectionDaemonBTKit: BackgroundWorker, RuuviTagConnectionDaemon {
    
    var scanner: BTScanner!
    var ruuviTagPersistence: RuuviTagPersistence!
    var settings: Settings!
    
    private var scanToken: ObservationToken?
    private var realm: Realm!
    private var isOnToken: NSObjectProtocol?
    private var syncInterval: TimeInterval {
        return TimeInterval(settings.connectionDaemonIntervalMinutes * 60)
    }
    
    lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
    
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
            sSelf.realm = try! Realm()
            sSelf.scanToken = sSelf.scanner.scan(sSelf, options: [.callbackQueue(.untouch)]) { (observer, device) in
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
        scanToken?.invalidate()
        stopWork()
    }
    
    @objc private func onDidReceiveConnectableTagAdvertisement(ruuviTagWrapped: RuuviTagConnectableDaemonWrapper) {
        let device = ruuviTagWrapped.device
        let operationIsAlreadyInQueue = queue.operations.contains(where: { ($0 as? RuuviTagConnectAndReadLogsOperation)?.uuid == device.uuid })
        if !operationIsAlreadyInQueue, !device.isConnected,  let ruuviTag = realm.object(ofType: RuuviTagRealm.self, forPrimaryKey: device.uuid), needsToConnectAndLoadData(for: ruuviTag) {
            let operation = RuuviTagConnectAndReadLogsOperation(ruuviTagPersistence: ruuviTagPersistence, logSyncDate: ruuviTag.logSyncDate, device: device)
            queue.addOperation(operation)
        }
    }
    
    private func needsToConnectAndLoadData(for ruuviTag: RuuviTagRealm) -> Bool {
        if let logSyncDate = ruuviTag.logSyncDate {
            return Date().timeIntervalSince(logSyncDate) > syncInterval
        } else {
            return true
        }
    }
    
}
