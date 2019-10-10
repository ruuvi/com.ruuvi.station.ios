import Foundation
import RealmSwift
import BTKit

class RuuviTagConnectionDaemonBTKit: BackgroundWorker, RuuviTagConnectionDaemon {
    
    var scanner: BTScanner!
    
    private var scanToken: ObservationToken?
    
    lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Load data from connectable Ruuvi Tags Queue"
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
    
    deinit {
        scanToken?.invalidate()
    }
    
    func start() {
        start { [weak self] in
            guard let sSelf = self else { return }
            sSelf.scanToken = sSelf.scanner.scan(sSelf, options: [.callbackQueue(.untouch)]) { (observer, device) in
                if let ruuviTag = device.ruuvi?.tag, ruuviTag.isConnectable {
                    print("found connectable tag")
                }
            }
        }
    }
    
    func stop() {
        scanToken?.invalidate()
    }
    
}
