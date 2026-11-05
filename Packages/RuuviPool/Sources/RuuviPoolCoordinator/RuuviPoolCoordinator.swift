#if SWIFT_PACKAGE
    import RuuviPool
#endif
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPersistence

// swiftlint:disable:next type_body_length
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

    @MainActor
    func create(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        guard let macId = ruuviTag.macId, !macId.value.isEmpty else {
            throw .ruuviPersistence(.failedToFindRuuviTag)
        }
        do {
            let created = try await sqlite.create(ruuviTag)
            if created, let luid = ruuviTag.luid {
                idPersistence.set(mac: macId, for: luid)
                idPersistence.set(luid: luid, for: macId)
            }
            return created
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    @MainActor
    func update(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        guard let macId = ruuviTag.macId, !macId.value.isEmpty else {
            throw .ruuviPersistence(.failedToFindRuuviTag)
        }
        do {
            let updated = try await sqlite.update(ruuviTag)
            if updated, let luid = ruuviTag.luid {
                idPersistence.set(mac: macId, for: luid)
                idPersistence.set(luid: luid, for: macId)
            }
            return updated
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    @MainActor
    func delete(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        guard let macId = ruuviTag.macId, !macId.value.isEmpty else {
            throw .ruuviPersistence(.failedToFindRuuviTag)
        }
        do {
            // Persistence removes the sensor and its calibration in the same transaction.
            let deleted = try await sqlite.delete(ruuviTag)
            if let luid = ruuviTag.luid {
                connectionPersistence.setKeepConnection(false, for: luid)
            }
            return deleted
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    @MainActor
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>
        do {
            let success = try await sqlite.deleteSensorSettings(ruuviTag)
            outcome = .success(success)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    @MainActor
    func create(_ record: RuuviTagSensorRecord) async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>
        if let macId = record.macId, !macId.value.isEmpty {
            do {
                let success = try await sqlite.create(record)
                outcome = .success(success)
            } catch let error {
                outcome = .failure(.ruuviPersistence(error))
            }
        } else if let luid = record.luid,
            let macId = idPersistence.mac(for: luid), !macId.value.isEmpty
        {
            do {
                let success = try await sqlite.create(record.with(macId: macId))
                outcome = .success(success)
            } catch let error {
                outcome = .failure(.ruuviPersistence(error))
            }
        } else {
            throw .ruuviPersistence(.failedToFindRuuviTag)
        }
        return try outcome.get()
    }

    @MainActor
    func createLast(_ record: RuuviTagSensorRecord) async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>
        if let macId = record.macId, !macId.value.isEmpty {
            do {
                let success = try await sqlite.createLast(record)
                outcome = .success(success)
            } catch let error {
                outcome = .failure(.ruuviPersistence(error))
            }
        } else if let luid = record.luid,
            let macId = idPersistence.mac(for: luid), !macId.value.isEmpty
        {
            do {
                let success = try await sqlite.createLast(record.with(macId: macId))
                outcome = .success(success)
            } catch let error {
                outcome = .failure(.ruuviPersistence(error))
            }
        } else {
            throw .ruuviPersistence(.failedToFindRuuviTag)
        }
        return try outcome.get()
    }

    @MainActor
    func updateLast(_ record: RuuviTagSensorRecord) async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>
        if let macId = record.macId, !macId.value.isEmpty {
            do {
                let success = try await sqlite.updateLast(record)
                outcome = .success(success)
            } catch let error {
                outcome = .failure(.ruuviPersistence(error))
            }
        } else if let luid = record.luid,
            let macId = idPersistence.mac(for: luid), !macId.value.isEmpty
        {
            do {
                let success = try await sqlite.updateLast(record.with(macId: macId))
                outcome = .success(success)
            } catch let error {
                outcome = .failure(.ruuviPersistence(error))
            }
        } else {
            throw .ruuviPersistence(.failedToFindRuuviTag)
        }
        return try outcome.get()
    }

    @MainActor
    func deleteLast(_ ruuviTagId: String) async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>

        do {
            let _ = try await sqlite.deleteLatest(ruuviTagId)
            outcome = .success(true)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    @MainActor
    func create(_ records: [RuuviTagSensorRecord]) async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>
        var sqliteRecords: [RuuviTagSensorRecord] = []
        for record in records {
            if let macId = record.macId, !macId.value.isEmpty {
                sqliteRecords.append(record)
            } else if let luid = record.luid,
                let macId = idPersistence.mac(for: luid), !macId.value.isEmpty
            {
                sqliteRecords.append(record.with(macId: macId))
            } else {
                // Reject the whole batch before writing; reporting success must never discard measurements.
                throw .ruuviPersistence(.failedToFindRuuviTag)
            }
        }

        do {
            let _ = try await sqlite.create(sqliteRecords)
            outcome = .success(true)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    @MainActor
    func deleteAllRecords(_ ruuviTagId: String) async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>

        do {
            let _ = try await sqlite.deleteAllRecords(ruuviTagId)
            outcome = .success(true)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    @MainActor
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>

        do {
            let _ = try await sqlite.deleteAllRecords(ruuviTagId, before: date)
            outcome = .success(true)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    func cleanupDBSpace() async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>
        do {
            let _ = try await sqlite.cleanupDBSpace()
            outcome = .success(true)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    @MainActor
    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws(RuuviPoolError) -> SensorSettings {
        var outcome: Result<SensorSettings, RuuviPoolError>
        if ruuviTag.macId != nil {
            do {
                let settings = try await sqlite.updateOffsetCorrection(
                    type: type,
                    with: value,
                    of: ruuviTag,
                    lastOriginalRecord: record
                )
                outcome = .success(settings)
            } catch let error {
                outcome = .failure(.ruuviPersistence(error))
            }
        } else {
            throw .ruuviPersistence(.failedToFindRuuviTag)
        }
        return try outcome.get()
    }

    @MainActor
    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) async throws(RuuviPoolError) -> SensorSettings {
        var outcome: Result<SensorSettings, RuuviPoolError>
        do {
            let settings = try await sqlite.updateDisplaySettings(
                for: ruuviTag,
                displayOrder: displayOrder,
                defaultDisplayOrder: defaultDisplayOrder,
                displayOrderLastUpdated: displayOrderLastUpdated,
                defaultDisplayOrderLastUpdated: defaultDisplayOrderLastUpdated
            )
            outcome = .success(settings)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    @MainActor
    func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws(RuuviPoolError) -> SensorSettings {
        var outcome: Result<SensorSettings, RuuviPoolError>
        do {
            let settings = try await sqlite.updateDescription(
                for: ruuviTag,
                description: description,
                descriptionLastUpdated: descriptionLastUpdated
            )
            outcome = .success(settings)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    @MainActor
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> SensorSettings? {
        var outcome: Result<SensorSettings?, RuuviPoolError>
        do {
            let settings = try await sqlite.readSensorSettings(ruuviTag)
            outcome = .success(settings)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    // MARK: - Queued cloud requests

    @MainActor
    func createQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>
        do {
            let success = try await sqlite.createQueuedRequest(request)
            outcome = .success(success)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    @MainActor
    func deleteQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>
        do {
            let success = try await sqlite.deleteQueuedRequest(request)
            outcome = .success(success)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    @MainActor
    func deleteQueuedRequests() async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>
        do {
            let success = try await sqlite.deleteQueuedRequests()
            outcome = .success(success)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    @MainActor
    func deleteUserSettings() async throws(RuuviPoolError) -> Bool {
        var outcome: Result<Bool, RuuviPoolError>
        do {
            let success = try await sqlite.deleteUserSettings()
            outcome = .success(success)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    // MARK: - Subscription
    @MainActor
    func save(
        subscription: CloudSensorSubscription
    ) async throws(RuuviPoolError) -> CloudSensorSubscription {
        var outcome: Result<CloudSensorSubscription, RuuviPoolError>
        do {
            let subscription = try await sqlite.save(subscription: subscription)
            outcome = .success(subscription)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }
        return try outcome.get()
    }

    @MainActor
    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws(RuuviPoolError) -> CloudSensorSubscription? {
        var outcome: Result<CloudSensorSubscription?, RuuviPoolError>
        let persistence = sqlite

        do {
            let subscription = try await persistence.readSensorSubscriptionSettings(ruuviTag)
            outcome = .success(subscription)
        } catch let error {
            outcome = .failure(.ruuviPersistence(error))
        }

        return try outcome.get()
    }
}
