import Foundation
import BTKit
import RealmSwift

extension Notification.Name {
    static let RuuviTagReadLogsOperationDidStart = Notification.Name("RuuviTagReadLogsOperationDidStart")
    static let RuuviTagReadLogsOperationDidFail = Notification.Name("RuuviTagReadLogsOperationDidFail")
    static let RuuviTagReadLogsOperationDidFinish = Notification.Name("RuuviTagReadLogsOperationDidFinish")
}

enum RuuviTagReadLogsOperationDidStartKey: String {
    case uuid
    case fromDate
}

enum RuuviTagReadLogsOperationDidFailKey: String {
    case uuid
    case error
}

enum RuuviTagReadLogsOperationDidFinishKey: String {
    case uuid
    case logs
}

class RuuviTagReadLogsOperation: AsyncOperation {

    var uuid: String
    var error: RUError?

    private var background: BTBackground
    private var connectionPersistence: ConnectionPersistence
    private var ruuviTagPersistence: RuuviTagPersistence
    private var logToken: ObservationToken?
    private var connectToken: ObservationToken?
    private var disconnectToken: ObservationToken?
    private var progress: ((BTServiceProgress) -> Void)?
    private var connectionTimeout: TimeInterval?
    private var serviceTimeout: TimeInterval?

    deinit {
        logToken?.invalidate()
        connectToken?.invalidate()
        disconnectToken?.invalidate()
    }

    init(uuid: String,
         ruuviTagPersistence: RuuviTagPersistence,
         connectionPersistence: ConnectionPersistence,
         background: BTBackground,
         progress: ((BTServiceProgress) -> Void)? = nil,
         connectionTimeout: TimeInterval? = 0,
         serviceTimeout: TimeInterval? = 0) {
        self.uuid = uuid
        self.ruuviTagPersistence = ruuviTagPersistence
        self.connectionPersistence = connectionPersistence
        self.background = background
        self.progress = progress
        self.connectionTimeout = connectionTimeout
        self.serviceTimeout = serviceTimeout
    }

    // swiftlint:disable:next function_body_length
    override func main() {
        let date = connectionPersistence.logSyncDate(uuid: uuid) ?? Date.distantPast
        let uuid = self.uuid
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .RuuviTagReadLogsOperationDidStart,
                                            object: nil,
                                            userInfo:
                [RuuviTagReadLogsOperationDidStartKey.uuid: uuid,
                 RuuviTagReadLogsOperationDidStartKey.fromDate: date])
        }

        background.services.ruuvi.nus.log(for: self,
                                          uuid: uuid,
                                          from: date,
                                          options: [.callbackQueue(.untouch),
                                                    .connectionTimeout(connectionTimeout ?? 0), .
                                                        serviceTimeout(serviceTimeout ?? 0)],
                                          progress: progress) { (observer, result) in
            switch result {
            case .success(let logs):
                let opLogs = observer.ruuviTagPersistence.persist(logs: logs, for: observer.uuid)
                opLogs.on(success: { _ in
                    observer.connectionPersistence.setLogSyncDate(Date(), uuid: observer.uuid)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .RuuviTagReadLogsOperationDidFinish,
                                                        object: nil,
                                                        userInfo:
                            [RuuviTagReadLogsOperationDidFinishKey.uuid: uuid,
                             RuuviTagReadLogsOperationDidFinishKey.logs: logs])
                    }
                    observer.state = .finished
                }, failure: { error in
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .RuuviTagReadLogsOperationDidFail,
                                                        object: nil,
                                                        userInfo:
                            [RuuviTagReadLogsOperationDidFailKey.uuid: uuid,
                             RuuviTagReadLogsOperationDidFailKey.error: error])
                    }
                    observer.error = error
                    observer.state = .finished
                })
            case .failure(let error):
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .RuuviTagReadLogsOperationDidFail,
                                                    object: nil,
                                                    userInfo:
                        [RuuviTagReadLogsOperationDidFailKey.uuid: uuid,
                         RuuviTagReadLogsOperationDidFailKey.error: error])
                }
                observer.error = .btkit(error)
                observer.state = .finished
            }
        }
    }
}
