import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviRepository

/// Actor that manages concurrency limiting for cloud sync operations
private actor CloudSyncConcurrencyLimiter {
    static let shared = CloudSyncConcurrencyLimiter()

    private let maxConcurrentSyncs = 3
    private var activeSyncs = 0
    private var waitingContinuations: [CheckedContinuation<Void, Never>] = []

    func waitForSlot() async {
        if activeSyncs < maxConcurrentSyncs {
            activeSyncs += 1
            return
        }

        await withCheckedContinuation { continuation in
            waitingContinuations.append(continuation)
        }
        activeSyncs += 1
    }

    func releaseSlot() {
        activeSyncs -= 1
        if let continuation = waitingContinuations.first {
            waitingContinuations.removeFirst()
            continuation.resume()
        }
    }
}

/// Cloud sync records loader using structured concurrency
public final class RuuviCloudSyncRecordsLoader: Sendable {
    private let ruuviCloud: RuuviCloud
    private let ruuviRepository: RuuviRepository
    private let ruuviLocalIDs: RuuviLocalIDs

    public init(
        ruuviCloud: RuuviCloud,
        ruuviRepository: RuuviRepository,
        ruuviLocalIDs: RuuviLocalIDs
    ) {
        self.ruuviCloud = ruuviCloud
        self.ruuviRepository = ruuviRepository
        self.ruuviLocalIDs = ruuviLocalIDs
    }

    public func loadRecords(
        sensor: RuuviTagSensor,
        since: Date,
        until: Date? = nil
    ) async throws -> [AnyRuuviTagSensorRecord] {
        guard let macId = sensor.macId else {
            throw RuuviServiceError.macIdIsNil
        }

        // Wait for a slot if we're at capacity
        await CloudSyncConcurrencyLimiter.shared.waitForSlot()
        defer {
            Task { await CloudSyncConcurrencyLimiter.shared.releaseSlot() }
        }

        let loadedRecords: [AnyRuuviTagSensorRecord]
        do {
            loadedRecords = try await ruuviCloud.loadRecords(
                macId: macId,
                since: since,
                until: until
            )
        } catch let cloudError as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(cloudError)
        }

        guard !loadedRecords.isEmpty else {
            return []
        }

        var recordsWithLuid: [AnyRuuviTagSensorRecord] = []
        for record in loadedRecords {
            if record.luid == nil,
               let macId = record.macId,
               let luid = await ruuviLocalIDs.luid(for: macId) {
                recordsWithLuid.append(record.with(luid: luid).any)
            } else {
                recordsWithLuid.append(record)
            }
        }

        do {
            _ = try await ruuviRepository.create(
                records: recordsWithLuid,
                for: sensor
            )
            return recordsWithLuid
        } catch let repositoryError as RuuviRepositoryError {
            throw RuuviServiceError.ruuviRepository(repositoryError)
        }
    }
}
