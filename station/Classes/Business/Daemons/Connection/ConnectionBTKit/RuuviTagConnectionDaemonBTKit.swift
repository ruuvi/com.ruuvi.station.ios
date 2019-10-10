import Foundation
import RealmSwift
import BTKit

class RuuviTagConnectionDaemonBTKit: BackgroundWorker, RuuviTagConnectionDaemon {
    
    var scanner: BTScanner!
    
    private var scanToken: ObservationToken?
    private var realm: Realm!
    private let syncInterval: TimeInterval = 5 * 60
    
    lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Load data from connectable Ruuvi Tags Queue"
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
    }
    
    func start() {
        start { [weak self] in
            guard let sSelf = self else { return }
            sSelf.realm = try! Realm()
            sSelf.scanToken = sSelf.scanner.scan(sSelf, options: [.callbackQueue(.untouch)]) { (observer, device) in
                if let ruuviTag = device.ruuvi?.tag, ruuviTag.isConnectable {
                    sSelf.perform(#selector(RuuviTagConnectionDaemonBTKit.onDidReceiveConnectableTagBroadcast(ruuviTagWrapped:)),
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
    }
    
    @objc private func onDidReceiveConnectableTagBroadcast(ruuviTagWrapped: RuuviTagConnectableDaemonWrapper) {
        let device = ruuviTagWrapped.device
        if !device.isConnected, let ruuviTag = realm.object(ofType: RuuviTagRealm.self, forPrimaryKey: device.uuid), needsToConnectAndLoadData(for: ruuviTag) {
            print(device)
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
