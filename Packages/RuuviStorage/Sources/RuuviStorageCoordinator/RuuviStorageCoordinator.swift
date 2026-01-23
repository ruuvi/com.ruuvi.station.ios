import Foundation
import RuuviOntology
import RuuviPersistence

actor RuuviStorageCoordinator: RuuviStorage {
    private let sqlite: RuuviPersistence

    init(sqlite: RuuviPersistence) {
        self.sqlite = sqlite
    }

    private func mapPersistenceError<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as RuuviPersistenceError {
            throw RuuviStorageError.ruuviPersistence(error)
        } catch {
            throw RuuviStorageError.ruuviPersistence(.grdb(error))
        }
    }

    func readOne(_ ruuviTagId: String) async throws -> AnyRuuviTagSensor {
        try await mapPersistenceError {
            try await sqlite.readOne(ruuviTagId)
        }
    }

    func readAll(_ ruuviTagId: String) async throws -> [RuuviTagSensorRecord] {
        try await mapPersistenceError {
            try await sqlite.readAll(ruuviTagId)
        }
    }

    func readAll() async throws -> [AnyRuuviTagSensor] {
        let sqliteEntities = try await mapPersistenceError {
            try await sqlite.readAll()
        }
        return sqliteEntities.map(\.any)
    }

    func readAll(_ id: String, after date: Date) async throws -> [RuuviTagSensorRecord] {
        try await mapPersistenceError {
            try await sqlite.readAll(id, after: date)
        }
    }

    func read(
        _ id: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        try await mapPersistenceError {
            try await sqlite.read(id, after: date, with: interval)
        }
    }

    func readDownsampled(
        _ id: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws -> [RuuviTagSensorRecord] {
        try await mapPersistenceError {
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
        try await mapPersistenceError {
            try await sqlite.readAll(id, with: interval)
        }
    }

    func readLast(_ id: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] {
        try await mapPersistenceError {
            try await sqlite.readLast(id, from: from)
        }
    }

    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        guard ruuviTag.macId != nil else {
            assertionFailure()
            throw RuuviStorageError.ruuviPersistence(.failedToFindRuuviTag)
        }
        return try await mapPersistenceError {
            try await sqlite.readLast(ruuviTag)
        }
    }

    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        guard ruuviTag.macId != nil else {
            assertionFailure()
            throw RuuviStorageError.ruuviPersistence(.failedToFindRuuviTag)
        }
        return try await mapPersistenceError {
            try await sqlite.readLatest(ruuviTag)
        }
    }

    func getStoredTagsCount() async throws -> Int {
        try await mapPersistenceError {
            try await sqlite.getStoredTagsCount()
        }
    }

    func getClaimedTagsCount() async throws -> Int {
        let tags = try await readAll()
        let claimedTags = tags.filter { $0.isClaimed && $0.isOwner }
        return claimedTags.count
    }

    func getOfflineTagsCount() async throws -> Int {
        let tags = try await readAll()
        let offlineTags = tags.filter { !$0.isCloud }
        return offlineTags.count
    }

    func getStoredMeasurementsCount() async throws -> Int {
        try await mapPersistenceError {
            try await sqlite.getStoredMeasurementsCount()
        }
    }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        guard ruuviTag.macId != nil else {
            assertionFailure()
            throw RuuviStorageError.ruuviPersistence(.failedToFindRuuviTag)
        }
        return try await mapPersistenceError {
            try await sqlite.readSensorSettings(ruuviTag)
        }
    }

    // MARK: - Queued cloud requests

    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] {
        try await mapPersistenceError {
            try await sqlite.readQueuedRequests()
        }
    }

    func readQueuedRequests(
        for key: String
    ) async throws -> [RuuviCloudQueuedRequest] {
        try await mapPersistenceError {
            try await sqlite.readQueuedRequests(for: key)
        }
    }

    func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) async throws -> [RuuviCloudQueuedRequest] {
        try await mapPersistenceError {
            try await sqlite.readQueuedRequests(for: type)
        }
    }
}
