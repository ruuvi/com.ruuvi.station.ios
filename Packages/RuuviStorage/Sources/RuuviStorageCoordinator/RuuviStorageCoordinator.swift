import Foundation
import RuuviOntology
import RuuviPersistence

final class RuuviStorageCoordinator: RuuviStorage {
    private let sqlite: RuuviPersistence

    init(sqlite: RuuviPersistence) {
        self.sqlite = sqlite
    }

    func readOne(_ ruuviTagId: String) async throws -> AnyRuuviTagSensor {
        try await storageOperation {
            try await sqlite.readOne(ruuviTagId)
        }
    }

    func readAll(_ ruuviTagId: String) async throws -> [RuuviTagSensorRecord] {
        try await storageOperation {
            try await sqlite.readAll(ruuviTagId)
        }
    }

    func readAll() async throws -> [AnyRuuviTagSensor] {
        try await storageOperation {
            try await sqlite.readAll()
        }
    }

    func readAll(_ id: String, after date: Date) async throws -> [RuuviTagSensorRecord] {
        try await storageOperation {
            try await sqlite.readAll(id, after: date)
        }
    }

    func read(
        _ id: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        try await storageOperation {
            try await sqlite.read(id, after: date, with: interval)
        }
    }

    func readDownsampled(
        _ id: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws -> [RuuviTagSensorRecord] {
        try await storageOperation {
            try await sqlite.readDownsampled(
                id,
                after: date,
                with: intervalMinutes,
                pick: points
            )
        }
    }

    func readAll(
        _ id: String,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        try await storageOperation {
            try await sqlite.readAll(id, with: interval)
        }
    }

    func readLast(_ id: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] {
        try await storageOperation {
            try await sqlite.readLast(id, from: from)
        }
    }

    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        guard ruuviTag.macId != nil else {
            return nil
        }
        return try await storageOperation {
            try await sqlite.readLast(ruuviTag)
        }
    }

    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        guard ruuviTag.macId != nil else {
            return nil
        }
        return try await storageOperation {
            try await sqlite.readLatest(ruuviTag)
        }
    }

    func getStoredTagsCount() async throws -> Int {
        try await storageOperation {
            try await sqlite.getStoredTagsCount()
        }
    }

    func getClaimedTagsCount() async throws -> Int {
        try await storageOperation {
            let tags = try await sqlite.readAll()
            return tags.filter { $0.isClaimed && $0.isOwner }.count
        }
    }

    func getOfflineTagsCount() async throws -> Int {
        try await storageOperation {
            let tags = try await sqlite.readAll()
            return tags.filter { !$0.isCloud }.count
        }
    }

    func getStoredMeasurementsCount() async throws -> Int {
        try await storageOperation {
            try await sqlite.getStoredMeasurementsCount()
        }
    }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        guard ruuviTag.macId != nil else {
            return nil
        }
        return try await storageOperation {
            try await sqlite.readSensorSettings(ruuviTag)
        }
    }

    // MARK: - Queued cloud requests

    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] {
        try await storageOperation {
            try await sqlite.readQueuedRequests()
        }
    }

    func readQueuedRequests(
        for key: String
    ) async throws -> [RuuviCloudQueuedRequest] {
        try await storageOperation {
            try await sqlite.readQueuedRequests(for: key)
        }
    }

    func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) async throws -> [RuuviCloudQueuedRequest] {
        try await storageOperation {
            try await sqlite.readQueuedRequests(for: type)
        }
    }
}

private extension RuuviStorageCoordinator {
    func storageOperation<Value>(
        _ operation: () async throws -> Value
    ) async throws -> Value {
        do {
            return try await operation()
        } catch let error as RuuviStorageError {
            throw error
        } catch let error as RuuviPersistenceError {
            throw RuuviStorageError.ruuviPersistence(error)
        } catch {
            throw RuuviStorageError.ruuviPersistence(.grdb(error))
        }
    }
}
