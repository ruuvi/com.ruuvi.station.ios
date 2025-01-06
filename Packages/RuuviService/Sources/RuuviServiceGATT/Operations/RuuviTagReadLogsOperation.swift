import BTKit
import Foundation
import RuuviOntology
import RuuviPool

final class RuuviTagReadLogsOperation: AsyncOperation, @unchecked Sendable {
    var uuid: String
    var mac: String?
    var sensorSettings: SensorSettings?
    var error: RuuviServiceError?

    private var background: BTBackground
    private var ruuviPool: RuuviPool
    private var progress: ((BTServiceProgress) -> Void)?
    private var connectionTimeout: TimeInterval?
    private var serviceTimeout: TimeInterval?
    private var from: Date

    init(
        uuid: String,
        mac: String?,
        from: Date,
        settings: SensorSettings?,
        ruuviPool: RuuviPool,
        background: BTBackground,
        progress: ((BTServiceProgress) -> Void)? = nil,
        connectionTimeout: TimeInterval? = 0,
        serviceTimeout: TimeInterval? = 0
    ) {
        self.uuid = uuid
        self.mac = mac
        self.from = from
        sensorSettings = settings
        self.ruuviPool = ruuviPool
        self.background = background
        self.progress = progress
        self.connectionTimeout = connectionTimeout
        self.serviceTimeout = serviceTimeout
    }

    override func main() {
        post(started: from, with: uuid)
        background.services.ruuvi.nus.log(
            for: self,
            uuid: uuid,
            from: from,
            options: [
                .callbackQueue(.untouch),
                .connectionTimeout(connectionTimeout ?? 0),
                .serviceTimeout(serviceTimeout ?? 0),
            ],
            progress: progress
        ) { observer, result in
            switch result {
            case let .success(logResult):
                switch logResult {
                case let .points(points):
                    observer.post(points: points, with: observer.uuid)
                case let .logs(logs):
                    let records = logs.compactMap { $0.ruuviSensorRecord(uuid: observer.uuid, mac: observer.mac)
                        .with(source: .log)
                        .any
                    }
                    let opLogs = observer.ruuviPool.create(records)
                    opLogs.on(success: { _ in
                        observer.post(logs: logs, with: observer.uuid)
                        observer.state = .finished
                    }, failure: { error in
                        observer.post(error: error, with: observer.uuid)
                        observer.error = .ruuviPool(error)
                        observer.state = .finished
                    })
                }
            case let .failure(error):
                observer.post(error: error, with: observer.uuid)
                observer.error = .btkit(error)
                observer.state = .finished
            }
        }
    }

    public func stopSync() {
        background.services.ruuvi.nus.disconnect(
            for: self,
            uuid: uuid,
            options: [],
            result: { _, _ in }
        )
    }

    private func post(started date: Date, with uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .RuuviTagReadLogsOperationDidStart,
                object: nil,
                userInfo:
                [
                    RuuviTagReadLogsOperationDidStartKey.uuid: uuid,
                    RuuviTagReadLogsOperationDidStartKey.fromDate: date,
                ]
            )
        }
    }

    private func post(points: Int, with uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .RuuviTagReadLogsOperationProgress,
                object: nil,
                userInfo:
                [
                    RuuviTagReadLogsOperationProgressKey.uuid: uuid,
                    RuuviTagReadLogsOperationProgressKey.progress: points,
                ]
            )
        }
    }

    private func post(logs: [RuuviTagEnvLogFull], with uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .RuuviTagReadLogsOperationDidFinish,
                object: nil,
                userInfo:
                [
                    RuuviTagReadLogsOperationDidFinishKey.uuid: uuid,
                    RuuviTagReadLogsOperationDidFinishKey.logs: logs,
                ]
            )
        }
    }

    private func post(error: Error, with uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .RuuviTagReadLogsOperationDidFail,
                object: nil,
                userInfo:
                [
                    RuuviTagReadLogsOperationDidFailKey.uuid: uuid,
                    RuuviTagReadLogsOperationDidFailKey.error: error,
                ]
            )
        }
    }
}
