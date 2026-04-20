import BTKit
import Foundation
import RuuviOntology
import RuuviPool

protocol RuuviTagReadLogsOperable: AnyObject {
    var uuid: String { get }
    var error: RuuviServiceError? { get }
    var isExecuting: Bool { get }
    var isFinished: Bool { get }
    var isCancelled: Bool { get }
    func cancel()
    func stopSync()
}

enum RuuviTagReadLogsServiceKind: Equatable {
    case e1
    case all

    var btService: BTRuuviNUSService {
        switch self {
        case .e1:
            .e1
        case .all:
            .all
        }
    }
}

struct RuuviTagReadLogsRequestContext {
    let uuid: String
    let from: Date
    let service: RuuviTagReadLogsServiceKind
    let progress: ((BTServiceProgress) -> Void)?
    let connectionTimeout: TimeInterval
    let serviceTimeout: TimeInterval
}

enum RuuviTagReadLogsCallbackResult {
    case points(Int)
    case logs([RuuviTagEnvLogFull])
    case failure(BTError)
}

final class RuuviTagReadLogsOperation: AsyncOperation, @unchecked Sendable {
    typealias LogReader = (
        RuuviTagReadLogsOperation,
        RuuviTagReadLogsRequestContext,
        @escaping (RuuviTagReadLogsCallbackResult) -> Void
    ) -> Void
    typealias DisconnectHandler = (RuuviTagReadLogsOperation, String) -> Void
    typealias RecordsSaver = @Sendable ([RuuviTagSensorRecord]) async throws -> Bool
    typealias LogMapper = ([RuuviTagEnvLogFull], String, String?) -> [RuuviTagSensorRecord]
    typealias BackgroundLogAction = (
        RuuviTagReadLogsOperation,
        String,
        Date,
        BTRuuviNUSService,
        BTScannerOptionsInfo?,
        ((BTServiceProgress) -> Void)?,
        @escaping (RuuviTagReadLogsOperation, Result<Progressable, BTError>) -> Void
    ) -> Void
    typealias BackgroundDisconnectAction = (RuuviTagReadLogsOperation, String) -> Void

    var uuid: String
    var mac: String?
    var firmware: Int
    var sensorSettings: SensorSettings?
    var error: RuuviServiceError?

    private var progress: ((BTServiceProgress) -> Void)?
    private var connectionTimeout: TimeInterval?
    private var serviceTimeout: TimeInterval?
    private var from: Date
    private let logReader: LogReader
    private let disconnectHandler: DisconnectHandler
    private let recordsSaver: RecordsSaver
    private let logMapper: LogMapper

    static let defaultLogMapper: LogMapper = { logs, uuid, mac in
        logs.compactMap {
            $0.ruuviSensorRecord(
                uuid: uuid,
                mac: mac
            )
            .with(source: .log)
        }
    }

    static func makeLogReader(
        backgroundLog: @escaping BackgroundLogAction
    ) -> LogReader {
        { observer, context, completion in
            backgroundLog(
                observer,
                context.uuid,
                context.from,
                context.service.btService,
                [
                    .callbackQueue(.untouch),
                    .connectionTimeout(context.connectionTimeout),
                    .serviceTimeout(context.serviceTimeout),
                ],
                context.progress
            ) { _, result in
                switch result {
                case let .success(logResult):
                    switch logResult {
                    case let .points(points):
                        completion(.points(points))
                    case let .logs(logs):
                        completion(.logs(logs))
                    }
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }

    static func makeDisconnectHandler(
        backgroundDisconnect: @escaping BackgroundDisconnectAction
    ) -> DisconnectHandler {
        { observer, uuid in
            backgroundDisconnect(observer, uuid)
        }
    }

    static func makeBackgroundLogAction(
        background: BTBackground
    ) -> BackgroundLogAction {
        { observer, uuid, from, service, options, progress, result in
            background.services.ruuvi.nus.log(
                for: observer,
                uuid: uuid,
                from: from,
                service: service,
                options: options,
                progress: progress,
                result: result
            )
        }
    }

    static func makeBackgroundDisconnectAction(
        background: BTBackground
    ) -> BackgroundDisconnectAction {
        { observer, uuid in
            background.services.ruuvi.nus.disconnect(
                for: observer,
                uuid: uuid,
                options: [],
                result: { _, _ in }
            )
        }
    }

    static func makeRecordsSaver(
        ruuviPool: RuuviPool
    ) -> RecordsSaver {
        { records in
            try await ruuviPool.create(records)
        }
    }

    convenience init(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?,
        ruuviPool: RuuviPool,
        background: BTBackground,
        progress: ((BTServiceProgress) -> Void)? = nil,
        connectionTimeout: TimeInterval? = 0,
        serviceTimeout: TimeInterval? = 0
    ) {
        self.init(
            uuid: uuid,
            mac: mac,
            firmware: firmware,
            from: from,
            settings: settings,
            progress: progress,
            connectionTimeout: connectionTimeout,
            serviceTimeout: serviceTimeout,
            logReader: Self.makeLogReader(
                backgroundLog: Self.makeBackgroundLogAction(background: background)
            ),
            disconnect: Self.makeDisconnectHandler(
                backgroundDisconnect: Self.makeBackgroundDisconnectAction(background: background)
            ),
            saveRecords: Self.makeRecordsSaver(ruuviPool: ruuviPool),
            logMapper: Self.defaultLogMapper
        )
    }

    init(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)? = nil,
        connectionTimeout: TimeInterval? = 0,
        serviceTimeout: TimeInterval? = 0,
        logReader: @escaping LogReader,
        disconnect: @escaping DisconnectHandler,
        saveRecords: @escaping RecordsSaver,
        logMapper: @escaping LogMapper
    ) {
        self.uuid = uuid
        self.mac = mac
        self.firmware = firmware
        self.from = from
        sensorSettings = settings
        self.progress = progress
        self.connectionTimeout = connectionTimeout
        self.serviceTimeout = serviceTimeout
        self.logReader = logReader
        disconnectHandler = disconnect
        recordsSaver = saveRecords
        self.logMapper = logMapper
    }

    override func main() {
        post(started: from, with: uuid)
        let context = RuuviTagReadLogsRequestContext(
            uuid: uuid,
            from: from,
            service: serviceKind,
            progress: progress,
            connectionTimeout: connectionTimeout ?? 0,
            serviceTimeout: serviceTimeout ?? 0
        )
        logReader(self, context) { [weak self] result in
            self?.handle(result)
        }
    }

    public func stopSync() {
        disconnectHandler(self, uuid)
    }

    private var serviceKind: RuuviTagReadLogsServiceKind {
        let firmwareVersion = RuuviDataFormat.dataFormat(from: firmware)
        return firmwareVersion == .e1 || firmwareVersion == .v6 ? .e1 : .all
    }

    private func handle(_ result: RuuviTagReadLogsCallbackResult) {
        switch result {
        case let .points(points):
            post(points: points, with: uuid)
        case let .logs(logs):
            let records = logMapper(logs, uuid, mac)
            Task {
                do {
                    _ = try await save(records)
                    post(logs: logs, with: uuid)
                    state = .finished
                } catch let error as RuuviPoolError {
                    post(error: error, with: uuid)
                    self.error = .ruuviPool(error)
                    state = .finished
                } catch {
                    let poolError = RuuviPoolError.ruuviPersistence(.grdb(error))
                    post(error: poolError, with: uuid)
                    self.error = .ruuviPool(poolError)
                    state = .finished
                }
            }
        case let .failure(error):
            post(error: error, with: uuid)
            self.error = .btkit(error)
            state = .finished
        }
    }

    private func save(_ records: [RuuviTagSensorRecord]) async throws -> Bool {
        try await recordsSaver(records)
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

extension RuuviTagReadLogsOperation: RuuviTagReadLogsOperable {}
