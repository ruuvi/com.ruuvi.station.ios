import Foundation
import BTKit
import RuuviOntology
import RuuviPool

final class RuuviTagReadLogsOperation: AsyncOperation {
    var uuid: String
    var mac: String?
    var sensorSettings: SensorSettings?
    var error: RuuviServiceError?

    private var background: BTBackground
    private var ruuviPool: RuuviPool
    private var progress: ((BTServiceProgress) -> Void)?
    private var connectionTimeout: TimeInterval?
    private var serviceTimeout: TimeInterval?

    init(
        uuid: String,
        mac: String?,
        settings: SensorSettings?,
        ruuviPool: RuuviPool,
        background: BTBackground,
        progress: ((BTServiceProgress) -> Void)? = nil,
        connectionTimeout: TimeInterval? = 0,
        serviceTimeout: TimeInterval? = 0
    ) {
        self.uuid = uuid
        self.mac = mac
        self.sensorSettings = settings
        self.ruuviPool = ruuviPool
        self.background = background
        self.progress = progress
        self.connectionTimeout = connectionTimeout
        self.serviceTimeout = serviceTimeout
    }

    override func main() {
        let date = Date.distantPast
        post(started: date, with: uuid)
        background.services.ruuvi.nus.log(for: self,
                                          uuid: uuid,
                                          from: date,
                                          options: [.callbackQueue(.untouch),
                                                    .connectionTimeout(connectionTimeout ?? 0),
                                                    .serviceTimeout(serviceTimeout ?? 0)],
                                          progress: progress) { (observer, result) in
            switch result {
            case .success(let logs):
                let records = logs.map({ $0.ruuviSensorRecord(uuid: observer.uuid, mac: observer.mac)
                    .with(source: .log)
                    .with(sensorSettings: observer.sensorSettings)
                })
                let opLogs = observer.ruuviPool.create(records)
                opLogs.on(success: { _ in
                    observer.post(logs: logs, with: observer.uuid)
                    observer.state = .finished
                }, failure: { error in
                    observer.post(error: error, with: observer.uuid)
                    observer.error = .ruuviPool(error)
                    observer.state = .finished
                })
            case .failure(let error):
                observer.post(error: error, with: observer.uuid)
                observer.error = .btkit(error)
                observer.state = .finished
            }
        }
    }

    private func post(started date: Date, with uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .RuuviTagReadLogsOperationDidStart,
                                            object: nil,
                                            userInfo:
                [RuuviTagReadLogsOperationDidStartKey.uuid: uuid,
                 RuuviTagReadLogsOperationDidStartKey.fromDate: date])
        }
    }

    private func post(logs: [RuuviTagEnvLogFull], with uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .RuuviTagReadLogsOperationDidFinish,
                                            object: nil,
                                            userInfo:
                [RuuviTagReadLogsOperationDidFinishKey.uuid: uuid,
                 RuuviTagReadLogsOperationDidFinishKey.logs: logs])
        }
    }

    private func post(error: Error, with uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .RuuviTagReadLogsOperationDidFail,
                                            object: nil,
                                            userInfo:
                [RuuviTagReadLogsOperationDidFailKey.uuid: uuid,
                 RuuviTagReadLogsOperationDidFailKey.error: error])
        }
    }
}
