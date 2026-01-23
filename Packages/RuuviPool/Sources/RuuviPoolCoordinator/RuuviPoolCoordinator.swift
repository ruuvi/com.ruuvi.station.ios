import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPersistence

// swiftlint:disable:next type_body_length
actor RuuviPoolCoordinator: RuuviPool {
    private let sqlite: RuuviPersistence
    private let idPersistence: RuuviLocalIDs
    private let settings: RuuviLocalSettings
    private let connectionPersistence: RuuviLocalConnections

    init(
        sqlite: RuuviPersistence,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings,
        connectionPersistence: RuuviLocalConnections
    ) {
        self.sqlite = sqlite
        self.idPersistence = idPersistence
        self.settings = settings
        self.connectionPersistence = connectionPersistence
    }

    private func mapPersistenceError<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as RuuviPersistenceError {
            throw RuuviPoolError.ruuviPersistence(error)
        } catch {
            throw RuuviPoolError.ruuviPersistence(.grdb(error))
        }
    }

    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        if let macId = ruuviTag.macId,
           let luid = ruuviTag.luid {
            idPersistence.set(mac: macId, for: luid)
        }
        guard let macId = ruuviTag.macId, macId.value.isEmpty == false else {
            assertionFailure()
            throw RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        }
        let result = try await mapPersistenceError {
            try await sqlite.create(ruuviTag)
        }
        if let luid = ruuviTag.luid {
            idPersistence.set(mac: macId, for: luid)
            idPersistence.set(luid: luid, for: macId)
        }
        return result
    }

    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        guard let macId = ruuviTag.macId else {
            assertionFailure()
            throw RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        }
        let result = try await mapPersistenceError {
            try await sqlite.update(ruuviTag)
        }
        if let luid = ruuviTag.luid {
            idPersistence.set(mac: macId, for: luid)
            idPersistence.set(luid: luid, for: macId)
        }
        return result
    }

    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        guard ruuviTag.macId != nil else {
            assertionFailure()
            throw RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        }
        _ = try await mapPersistenceError {
            try await sqlite.deleteOffsetCorrection(ruuviTag: ruuviTag)
        }
        let result = try await mapPersistenceError {
            try await sqlite.delete(ruuviTag)
        }
        if let luid = ruuviTag.luid {
            connectionPersistence.setKeepConnection(false, for: luid)
        }
        return result
    }

    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        try await mapPersistenceError {
            try await sqlite.deleteSensorSettings(ruuviTag)
        }
    }

    func create(_ record: RuuviTagSensorRecord) async throws -> Bool {
        if record.macId != nil {
            return try await mapPersistenceError {
                try await sqlite.create(record)
            }
        } else if let luid = record.luid,
                  let macId = idPersistence.mac(for: luid) {
            return try await mapPersistenceError {
                try await sqlite.create(record.with(macId: macId))
            }
        } else {
            assertionFailure()
            throw RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        }
    }

    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        if record.macId != nil {
            return try await mapPersistenceError {
                try await sqlite.createLast(record)
            }
        } else if let luid = record.luid,
                  let macId = idPersistence.mac(for: luid) {
            return try await mapPersistenceError {
                try await sqlite.createLast(record.with(macId: macId))
            }
        } else {
            assertionFailure()
            throw RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        }
    }

    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        if record.macId != nil {
            return try await mapPersistenceError {
                try await sqlite.updateLast(record)
            }
        } else if let luid = record.luid,
                  let macId = idPersistence.mac(for: luid) {
            return try await mapPersistenceError {
                try await sqlite.updateLast(record.with(macId: macId))
            }
        } else {
            assertionFailure()
            throw RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        }
    }

    func deleteLast(_ ruuviTagId: String) async throws -> Bool {
        _ = try await mapPersistenceError {
            try await sqlite.deleteLatest(ruuviTagId)
        }
        return true
    }

    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool {
        let sqliteRecords = records.filter { $0.macId != nil }
        _ = try await mapPersistenceError {
            try await sqlite.create(sqliteRecords)
        }
        return true
    }

    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool {
        _ = try await mapPersistenceError {
            try await sqlite.deleteAllRecords(ruuviTagId)
        }
        return true
    }

    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool {
        _ = try await mapPersistenceError {
            try await sqlite.deleteAllRecords(ruuviTagId, before: date)
        }
        return true
    }

    @discardableResult
    func cleanupDBSpace() async throws -> Bool {
        try await mapPersistenceError {
            try await sqlite.cleanupDBSpace()
        }
    }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        guard ruuviTag.macId != nil else {
            assertionFailure()
            throw RuuviPoolError.ruuviPersistence(.failedToFindRuuviTag)
        }
        return try await mapPersistenceError {
            try await sqlite.updateOffsetCorrection(
                type: type,
                with: value,
                of: ruuviTag,
                lastOriginalRecord: record
            )
        }
    }

    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?
    ) async throws -> SensorSettings {
        try await mapPersistenceError {
            try await sqlite.updateDisplaySettings(
                for: ruuviTag,
                displayOrder: displayOrder,
                defaultDisplayOrder: defaultDisplayOrder
            )
        }
    }

    // MARK: - Queued cloud requests

    func createQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws -> Bool {
        try await mapPersistenceError {
            try await sqlite.createQueuedRequest(request)
        }
    }

    func deleteQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws -> Bool {
        try await mapPersistenceError {
            try await sqlite.deleteQueuedRequest(request)
        }
    }

    func deleteQueuedRequests() async throws -> Bool {
        try await mapPersistenceError {
            try await sqlite.deleteQueuedRequests()
        }
    }

    // MARK: - Subscription
    func save(
        subscription: CloudSensorSubscription
    ) async throws -> CloudSensorSubscription {
        try await mapPersistenceError {
            try await sqlite.save(subscription: subscription)
        }
    }

    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws -> CloudSensorSubscription? {
        try await mapPersistenceError {
            try await sqlite.readSensorSubscriptionSettings(ruuviTag)
        }
    }
}
