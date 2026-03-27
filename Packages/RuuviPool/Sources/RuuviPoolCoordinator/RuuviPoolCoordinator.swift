import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPersistence

final class RuuviPoolCoordinator: RuuviPool {
    private var sqlite: RuuviPersistence
    private var idPersistence: RuuviLocalIDs
    private var settings: RuuviLocalSettings
    private var connectionPersistence: RuuviLocalConnections

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

    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        if let macId = ruuviTag.macId,
           let luid = ruuviTag.luid {
            idPersistence.set(mac: macId, for: luid)
        }

        guard ruuviTag.macId != nil,
              ruuviTag.macId?.value.isEmpty == false
        else {
            assertionFailure()
            return false
        }

        let result = try await poolOperation {
            try await sqlite.create(ruuviTag)
        }

        if let macId = ruuviTag.macId, let luid = ruuviTag.luid {
            idPersistence.set(mac: macId, for: luid)
            idPersistence.set(luid: luid, for: macId)
        }
        return result
    }

    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        guard ruuviTag.macId != nil else {
            assertionFailure()
            return false
        }

        let success = try await poolOperation {
            try await sqlite.update(ruuviTag)
        }

        if let macId = ruuviTag.macId, let luid = ruuviTag.luid {
            idPersistence.set(mac: macId, for: luid)
            idPersistence.set(luid: luid, for: macId)
        }
        return success
    }

    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        guard ruuviTag.macId != nil else {
            assertionFailure()
            return false
        }

        let success = try await poolOperation {
            _ = try await sqlite.deleteOffsetCorrection(ruuviTag: ruuviTag)
            return try await sqlite.delete(ruuviTag)
        }

        if let luid = ruuviTag.luid {
            connectionPersistence.setKeepConnection(false, for: luid)
        }
        return success
    }

    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        try await poolOperation {
            try await sqlite.deleteSensorSettings(ruuviTag)
        }
    }

    func create(_ record: RuuviTagSensorRecord) async throws -> Bool {
        if record.macId != nil {
            return try await poolOperation {
                try await sqlite.create(record)
            }
        }

        if let luid = record.luid,
           let macId = idPersistence.mac(for: luid) {
            return try await poolOperation {
                try await sqlite.create(record.with(macId: macId))
            }
        }

        assertionFailure()
        return false
    }

    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        if record.macId != nil {
            return try await poolOperation {
                try await sqlite.createLast(record)
            }
        }

        if let luid = record.luid,
           let macId = idPersistence.mac(for: luid) {
            return try await poolOperation {
                try await sqlite.createLast(record.with(macId: macId))
            }
        }

        assertionFailure()
        return false
    }

    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        if record.macId != nil {
            return try await poolOperation {
                try await sqlite.updateLast(record)
            }
        }

        if let luid = record.luid,
           let macId = idPersistence.mac(for: luid) {
            return try await poolOperation {
                try await sqlite.updateLast(record.with(macId: macId))
            }
        }

        assertionFailure()
        return false
    }

    func deleteLast(_ ruuviTagId: String) async throws -> Bool {
        try await poolOperation {
            _ = try await sqlite.deleteLatest(ruuviTagId)
            return true
        }
    }

    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool {
        try await poolOperation {
            let sqliteRecords = records.filter { $0.macId != nil }
            _ = try await sqlite.create(sqliteRecords)
            return true
        }
    }

    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool {
        try await poolOperation {
            _ = try await sqlite.deleteAllRecords(ruuviTagId)
            return true
        }
    }

    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool {
        try await poolOperation {
            _ = try await sqlite.deleteAllRecords(ruuviTagId, before: date)
            return true
        }
    }

    @discardableResult
    func cleanupDBSpace() async throws -> Bool {
        try await poolOperation {
            _ = try await sqlite.cleanupDBSpace()
            return true
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

        return try await poolOperation {
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
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) async throws -> SensorSettings {
        try await poolOperation {
            try await sqlite.updateDisplaySettings(
                for: ruuviTag,
                displayOrder: displayOrder,
                defaultDisplayOrder: defaultDisplayOrder,
                displayOrderLastUpdated: displayOrderLastUpdated,
                defaultDisplayOrderLastUpdated: defaultDisplayOrderLastUpdated
            )
        }
    }

    func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws -> SensorSettings {
        try await poolOperation {
            try await sqlite.updateDescription(
                for: ruuviTag,
                description: description,
                descriptionLastUpdated: descriptionLastUpdated
            )
        }
    }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        try await poolOperation {
            try await sqlite.readSensorSettings(ruuviTag)
        }
    }

    // MARK: - Queued cloud requests

    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool {
        try await poolOperation {
            try await sqlite.createQueuedRequest(request)
        }
    }

    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool {
        try await poolOperation {
            try await sqlite.deleteQueuedRequest(request)
        }
    }

    func deleteQueuedRequests() async throws -> Bool {
        try await poolOperation {
            try await sqlite.deleteQueuedRequests()
        }
    }

    // MARK: - Subscription

    func save(
        subscription: CloudSensorSubscription
    ) async throws -> CloudSensorSubscription {
        try await poolOperation {
            try await sqlite.save(subscription: subscription)
        }
    }

    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws -> CloudSensorSubscription? {
        try await poolOperation {
            try await sqlite.readSensorSubscriptionSettings(ruuviTag)
        }
    }
}

private extension RuuviPoolCoordinator {
    func poolOperation<Value>(
        _ operation: () async throws -> Value
    ) async throws -> Value {
        do {
            return try await operation()
        } catch let error as RuuviPoolError {
            throw error
        } catch let error as RuuviPersistenceError {
            throw RuuviPoolError.ruuviPersistence(error)
        } catch {
            throw RuuviPoolError.ruuviPersistence(.grdb(error))
        }
    }
}
