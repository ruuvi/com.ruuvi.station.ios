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
        let from = logSyncDate ?? Date.distantPast
//        connectToken = device.connect(for: self, options: [.callbackQueue(.untouch)], result: { (observer, result) in
//            observer.connectToken?.invalidate()
//            switch result {
//            case .failure(let error):
//                DispatchQueue.main.async {
//                    NotificationCenter.default.post(name: .RuuviTagConnectionDaemonDidFail, object: nil, userInfo: [RuuviTagConnectionDaemonDidFailKey.error: RUError.btkit(error)])
//                }
//                observer.state = .finished
//            case .disconnected:
//                observer.state = .finished
//            default:
//                observer.logToken = observer.device.log(for: observer, from: from, options: [.callbackQueue(.untouch)]) { (observer, result) in
//                    observer.logToken?.invalidate()
//                    switch result {
//                    case .success(let logs):
//                        let opLogs = observer.ruuviTagPersistence.persist(logs: logs, for: observer.device.uuid)
//                        opLogs.on(success: { _ in
//                            let opDate =  observer.ruuviTagPersistence.update(lastSyncDate: Date(), for: observer.device.uuid)
//                            opDate.on(success: { _ in
//                                observer.disconnect()
//                            }, failure: { error in
//                                DispatchQueue.main.async {
//                                    NotificationCenter.default.post(name: .RuuviTagConnectionDaemonDidFail, object: nil, userInfo: [RuuviTagConnectionDaemonDidFailKey.error: error])
//                                }
//                                observer.disconnect()
//                            })
//                        }, failure: { error in
//                            DispatchQueue.main.async {
//                                NotificationCenter.default.post(name: .RuuviTagConnectionDaemonDidFail, object: nil, userInfo: [RuuviTagConnectionDaemonDidFailKey.error: error])
//                            }
//                            observer.disconnect()
//                        })
//                    case .failure(let error):
//                        DispatchQueue.main.async {
//                            NotificationCenter.default.post(name: .RuuviTagConnectionDaemonDidFail, object: nil, userInfo: [RuuviTagConnectionDaemonDidFailKey.error: RUError.btkit(error)])
//                        }
//                        observer.disconnect()
//                    }
//                }
//            }
//        })
    }
    
    private func disconnect() {
        disconnectToken = device.disconnect(for: self, options: [.callbackQueue(.untouch)]) { (observer, result) in
            observer.disconnectToken?.invalidate()
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .RuuviTagConnectionDaemonDidFail, object: nil, userInfo: [RuuviTagConnectionDaemonDidFailKey.error: RUError.btkit(error)])
                }
                observer.disconnectToken?.invalidate()
                observer.state = .finished
            default:
                observer.state = .finished
            }
        }
    }
    
}
