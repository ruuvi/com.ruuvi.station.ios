import Foundation
import BTKit
import RealmSwift

class RuuviTagConnectAndReadLogsOperation: AsyncOperation {
    
    var uuid: String
    
    private var ruuviTag: RuuviTagRealm
    private var logSyncDate: Date?
    private var device: RuuviTag
    private var realm: Realm
    private var thread: Thread
    private var logToken: ObservationToken?
    private var connectToken: ObservationToken?
    private var disconnectToken: ObservationToken?
    
    deinit {
        logToken?.invalidate()
        connectToken?.invalidate()
        disconnectToken?.invalidate()
    }
    
    init(ruuviTag: RuuviTagRealm, logSyncDate: Date?, device: RuuviTag, realm: Realm, thread: Thread) {
        uuid = device.uuid
        self.ruuviTag = ruuviTag
        self.logSyncDate = logSyncDate
        self.device = device
        self.realm = realm
        self.thread = thread
    }
    
    override func main() {
        let from = logSyncDate ?? Date.distantPast
        connectToken = device.connect(for: self, result: { (observer, result) in
            observer.connectToken?.invalidate()
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
                observer.state = .finished
            case .disconnected:
                observer.state = .finished
            default:
                observer.logToken = observer.device.log(for: self, from: from) { (observer, result) in
                    observer.logToken?.invalidate()
                    switch result {
                    case .success(let logs):
                        print(logs)
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                    observer.disconnectToken = observer.device.disconnect(for: observer) { (observer, result) in
                        observer.disconnectToken?.invalidate()
                        switch result {
                        case .failure(let error):
                            print(error.localizedDescription)
                            observer.disconnectToken?.invalidate()
                            observer.state = .finished
                        default:
                            observer.state = .finished
                        }
                    }
                }
            }
        })
        
        
    }
    
}
