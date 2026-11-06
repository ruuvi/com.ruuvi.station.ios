#if SWIFT_PACKAGE
    import RuuviService
#endif
import BTKit
import Foundation
import RuuviOntology
import RuuviPool

final class RuuviTagReadLogsOperation: AsyncOperation {
    var uuid: String
    var mac: String?
    var firmware: Int
    var sensorSettings: SensorSettings?
    var error: RuuviServiceError?

    private let transport: RuuviLogTransport
    private var ruuviPool: RuuviPool
    private var progress: ((BTServiceProgress) -> Void)?
    private var connectionTimeout: TimeInterval?
    private var serviceTimeout: TimeInterval?
    private var from: Date
    private let resultLock = NSRecursiveLock()
    private let progressLock = NSLock()
    private var latestProgress: BTServiceProgress?
    private var hasTerminalResult = false
    private var persistenceTask: Task<Void, Never>?

    var currentProgress: BTServiceProgress? {
        progressLock.lock()
        defer { progressLock.unlock() }
        return latestProgress
    }

    init(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?,
        ruuviPool: RuuviPool,
        transport: RuuviLogTransport,
        progress: ((BTServiceProgress) -> Void)? = nil,
        connectionTimeout: TimeInterval? = 0,
        serviceTimeout: TimeInterval? = 0
    ) {
        self.uuid = uuid
        self.mac = mac
        self.firmware = firmware
        self.from = from
        sensorSettings = settings
        self.ruuviPool = ruuviPool
        self.transport = transport
        self.progress = progress
        self.connectionTimeout = connectionTimeout
        self.serviceTimeout = serviceTimeout
    }

    override func main() {
        // Cancellation can arrive after start transitions to executing but before main runs.
        resultLock.lock()
        defer { resultLock.unlock() }
        guard !isCancelled else { return }
        readLogs()
    }

    private func readLogs() {
        post(started: from, with: uuid)
        let firmwareVersion = RuuviDataFormat.dataFormat(from: firmware)
        transport.read(
            for: self,
            uuid: uuid,
            from: from,
            service: firmwareVersion == .e1 || firmwareVersion == .v6 ? .e1 : .all,
            connectionTimeout: connectionTimeout ?? 0,
            serviceTimeout: serviceTimeout ?? 0,
            progress: { [weak self] in self?.handle(progress: $0) }
        ) { observer, result in
            // Finish any persistence already in progress before cancellation returns.
            observer.resultLock.lock()
            defer { observer.resultLock.unlock() }
            guard !observer.isCancelled, !observer.hasTerminalResult else { return }
            switch result {
            case let .success(logResult):
                switch logResult {
                case let .points(points):
                    observer.post(progress: .reading(points), with: observer.uuid)
                case let .logs(logs):
                    observer.hasTerminalResult = true
                    let records = logs.compactMap {
                        $0.ruuviSensorRecord(
                            uuid: observer.uuid,
                            mac: observer.mac
                        )
                        .with(source: .log)
                        .any
                    }
                    observer.persistenceTask = Task {
                        guard !observer.isCancelled else { return }
                        do throws(RuuviPoolError) {
                            _ = try await observer.ruuviPool.create(records)
                            guard !observer.isCancelled else { return }
                            observer.post(logs: logs, with: observer.uuid)
                        } catch {
                            guard !observer.isCancelled else { return }
                            observer.post(error: error, with: observer.uuid)
                            observer.error = .ruuviPool(error)
                        }
                        observer.state = .finished
                    }
                }
            case let .failure(error):
                observer.hasTerminalResult = true
                observer.post(error: error, with: observer.uuid)
                observer.error = .btkit(error)
                observer.state = .finished
            }
        }
    }

    override func cancel() {
        resultLock.lock()
        defer { resultLock.unlock() }
        super.cancel()
        persistenceTask?.cancel()
    }

    func waitForPersistence() async {
        let task = resultLock.withLock { persistenceTask }
        await task?.value
    }

    public func stopSync() {
        transport.disconnect(for: self, uuid: uuid)
    }

    private func handle(progress: BTServiceProgress) {
        resultLock.lock()
        defer { resultLock.unlock() }
        guard !isCancelled, !hasTerminalResult else { return }
        post(progress: progress, with: uuid)
        self.progress?(progress)
    }

    private func post(started date: Date, with uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .RuuviTagReadLogsOperationDidStart,
                object: nil,
                userInfo: [
                    RuuviTagReadLogsOperationDidStartKey.uuid: uuid,
                    RuuviTagReadLogsOperationDidStartKey.fromDate: date,
                ]
            )
        }
    }

    private func post(progress: BTServiceProgress, with uuid: String) {
        progressLock.lock()
        latestProgress = progress
        progressLock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard self?.isCancelled == false else { return }
            var userInfo: [RuuviTagReadLogsOperationProgressKey: Any] = [
                .uuid: uuid,
                .serviceProgress: progress,
            ]
            if case let .reading(points) = progress {
                userInfo[.progress] = points
            }
            NotificationCenter.default.post(
                name: .RuuviTagReadLogsOperationProgress,
                object: nil,
                userInfo: userInfo
            )
        }
    }

    private func post(logs: [RuuviTagEnvLogFull], with uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .RuuviTagReadLogsOperationDidFinish,
                object: nil,
                userInfo: [
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
                userInfo: [
                    RuuviTagReadLogsOperationDidFailKey.uuid: uuid,
                    RuuviTagReadLogsOperationDidFailKey.error: error,
                ]
            )
        }
    }
}
