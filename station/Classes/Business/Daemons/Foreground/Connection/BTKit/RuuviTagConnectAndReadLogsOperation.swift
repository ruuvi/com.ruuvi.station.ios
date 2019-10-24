import Foundation
import BTKit
import RealmSwift

class RuuviTagConnectAndReadLogsOperation: AsyncOperation {
    
    var uuid: String
    
    private var ruuviTagPersistence: RuuviTagPersistence!
    private var logSyncDate: Date?
    private var device: RuuviTag
    private var logToken: ObservationToken?
    private var connectToken: ObservationToken?
    private var disconnectToken: ObservationToken?
    
    deinit {
        logToken?.invalidate()
        connectToken?.invalidate()
        disconnectToken?.invalidate()
    }
    
    init(ruuviTagPersistence: RuuviTagPersistence, logSyncDate: Date?, device: RuuviTag) {
        uuid = device.uuid
        self.ruuviTagPersistence = ruuviTagPersistence
        self.logSyncDate = logSyncDate
        self.device = device
    }
    
    override func main() {        
        let date = logSyncDate ?? Date.distantPast
        device.log(for: self, from: date, options: [.callbackQueue(.untouch)]) { (observer, result) in
            switch result {
            case .success(let logs):
                let opLogs = observer.ruuviTagPersistence.persist(logs: logs, for: observer.device.uuid)
                opLogs.on(success: { _ in
                    let opDate =  observer.ruuviTagPersistence.update(lastSyncDate: Date(), for: observer.device.uuid)
                    opDate.on(success: { _ in
                        observer.state = .finished
                    }, failure: { error in
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .RuuviTagConnectionDaemonDidFail, object: nil, userInfo: [RuuviTagConnectionDaemonDidFailKey.error: error])
                        }
                        observer.state = .finished
                    })
                })
            case .failure(let error):
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .RuuviTagConnectionDaemonDidFail, object: nil, userInfo: [RuuviTagConnectionDaemonDidFailKey.error: RUError.btkit(error)])
                }
                observer.state = .finished
            }
        }
    }
}
