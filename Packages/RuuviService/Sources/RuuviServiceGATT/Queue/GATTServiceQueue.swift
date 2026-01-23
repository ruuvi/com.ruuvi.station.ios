import BTKit
import Foundation
import RuuviOntology
import RuuviPool

/// Actor that manages GATT log sync operations with proper concurrency control
private actor GATTSyncManager {
    static let shared = GATTSyncManager()

    private var activeSyncs: [String: GATTSyncHandle] = [:]
    private let maxConcurrentSyncs = 3
    private var waitingContinuations: [CheckedContinuation<Void, Never>] = []
    private var activeCount = 0

    struct GATTSyncHandle {
        let uuid: String
        let background: BTBackground
        var isCancelled: Bool = false
    }

    func isSyncing(uuid: String) -> Bool {
        activeSyncs[uuid] != nil
    }

    func registerSync(uuid: String, background: BTBackground) async -> Bool {
        guard activeSyncs[uuid] == nil else {
            return false // Already syncing
        }

        // Wait for a slot if at capacity
        if activeCount >= maxConcurrentSyncs {
            await withCheckedContinuation { continuation in
                waitingContinuations.append(continuation)
            }
        }

        activeCount += 1
        activeSyncs[uuid] = GATTSyncHandle(uuid: uuid, background: background)
        return true
    }

    func unregisterSync(uuid: String) {
        activeSyncs.removeValue(forKey: uuid)
        activeCount -= 1

        // Resume next waiting sync if any
        if let continuation = waitingContinuations.first {
            waitingContinuations.removeFirst()
            continuation.resume()
        }
    }

    func cancelSync(uuid: String) -> Bool {
        guard var handle = activeSyncs[uuid] else {
            return false
        }
        handle.isCancelled = true
        activeSyncs[uuid] = handle

        // Disconnect from the device
        handle.background.services.ruuvi.nus.disconnect(
            for: self,
            uuid: uuid,
            options: [],
            result: { _, _ in }
        )
        return true
    }

    func isCancelled(uuid: String) -> Bool {
        activeSyncs[uuid]?.isCancelled ?? false
    }
}

public final class GATTServiceQueue: GATTService {
    private let ruuviPool: RuuviPool
    private let background: BTBackground

    public init(
        ruuviPool: RuuviPool,
        background: BTBackground
    ) {
        self.ruuviPool = ruuviPool
        self.background = background
    }

    @discardableResult
    // swiftlint:disable function_parameter_count
    public func syncLogs(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?,
        connectionTimeout: TimeInterval?,
        serviceTimeout: TimeInterval?
    ) async throws -> Bool {
        // Check if already syncing
        if await GATTSyncManager.shared.isSyncing(uuid: uuid) {
            throw RuuviServiceError.isAlreadySyncingLogsWithThisTag
        }

        // Register this sync (waits for slot if at capacity)
        guard await GATTSyncManager.shared.registerSync(uuid: uuid, background: background) else {
            throw RuuviServiceError.isAlreadySyncingLogsWithThisTag
        }

        defer {
            Task { await GATTSyncManager.shared.unregisterSync(uuid: uuid) }
        }

        // Post started notification
        postStartedNotification(from: from, uuid: uuid)

        let firmwareVersion = RuuviDataFormat.dataFormat(from: firmware)

        return try await withCheckedThrowingContinuation { continuation in
            background.services.ruuvi.nus.log(
                for: self,
                uuid: uuid,
                from: from,
                service: firmwareVersion == .e1 || firmwareVersion == .v6 ? .e1 : .all,
                options: [
                    .callbackQueue(.untouch),
                    .connectionTimeout(connectionTimeout ?? 0),
                    .serviceTimeout(serviceTimeout ?? 0),
                ],
                progress: progress
            ) { [weak self] _, result in
                guard let self else {
                    continuation.resume(throwing: RuuviServiceError.unexpectedError(
                        RuuviServiceErrorUnexpected.callerDeallocated
                    ))
                    return
                }

                switch result {
                case let .success(logResult):
                    switch logResult {
                    case let .points(points):
                        self.postProgressNotification(points: points, uuid: uuid)
                    case let .logs(logs):
                        let records = logs.compactMap {
                            $0.ruuviSensorRecord(uuid: uuid, mac: mac)
                                .with(source: .log)
                                .any
                        }
                        Task { [weak self] in
                            guard let self else { return }
                            do {
                                _ = try await self.ruuviPool.create(records)
                                self.postFinishedNotification(logs: logs, uuid: uuid)
                                continuation.resume(returning: true)
                            } catch let error as RuuviPoolError {
                                self.postFailedNotification(error: error, uuid: uuid)
                                continuation.resume(throwing: RuuviServiceError.ruuviPool(error))
                            }
                        }
                    }
                case let .failure(error):
                    self.postFailedNotification(error: error, uuid: uuid)
                    continuation.resume(throwing: RuuviServiceError.btkit(error))
                }
            }
        }
    }
    // swiftlint:enable function_parameter_count

    public func isSyncingLogs(with uuid: String) -> Bool {
        // Use nonisolated synchronous access pattern
        // This is safe because we're just reading a snapshot
        let result = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        result.initialize(to: false)
        defer { result.deallocate() }

        let group = DispatchGroup()
        group.enter()
        Task {
            result.pointee = await GATTSyncManager.shared.isSyncing(uuid: uuid)
            group.leave()
        }
        group.wait()
        return result.pointee
    }

    public func stopGattSync(for uuid: String) async throws -> Bool {
        await GATTSyncManager.shared.cancelSync(uuid: uuid)
    }

    // MARK: - Notifications

    private func postStartedNotification(from date: Date, uuid: String) {
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

    private func postProgressNotification(points: Int, uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .RuuviTagReadLogsOperationProgress,
                object: nil,
                userInfo: [
                    RuuviTagReadLogsOperationProgressKey.uuid: uuid,
                    RuuviTagReadLogsOperationProgressKey.progress: points,
                ]
            )
        }
    }

    private func postFinishedNotification(logs: [RuuviTagEnvLogFull], uuid: String) {
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

    private func postFailedNotification(error: Error, uuid: String) {
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
