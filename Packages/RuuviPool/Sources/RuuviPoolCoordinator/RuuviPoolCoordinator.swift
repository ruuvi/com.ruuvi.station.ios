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

    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        if let macId = ruuviTag.macId, let luid = ruuviTag.luid {
            idPersistence.set(mac: macId, for: luid)
        }
        guard let macId = ruuviTag.macId, !macId.value.isEmpty else { assertionFailure(); return false }
        do {
            let result = try await sqlite.create(ruuviTag)
            if let luid = ruuviTag.luid {
                idPersistence.set(mac: macId, for: luid)
                idPersistence.set(luid: luid, for: macId)
            }
            return result
        } catch { throw (error) }
    }

    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        guard let macId = ruuviTag.macId else { assertionFailure(); return false }
        do {
            let success = try await sqlite.update(ruuviTag)
            if let luid = ruuviTag.luid { idPersistence.set(mac: macId, for: luid); idPersistence.set(luid: luid, for: macId) }
            return success
        } catch { throw (error) }
    }

    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        guard ruuviTag.macId != nil else { assertionFailure(); return false }
        do {
            _ = try await sqlite.deleteOffsetCorrection(ruuviTag: ruuviTag)
            let success = try await sqlite.delete(ruuviTag)
            if let luid = ruuviTag.luid { connectionPersistence.setKeepConnection(false, for: luid) }
            return success
        } catch { throw (error) }
    }

    func create(_ record: RuuviTagSensorRecord) async throws -> Bool {
        do {
            if record.macId != nil { return try await sqlite.create(record) }
            if let luid = record.luid, let macId = idPersistence.mac(for: luid) {
                return try await sqlite.create(record.with(macId: macId))
            }
            assertionFailure(); return false
        } catch { throw (error) }
    }

    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        do {
            if record.macId != nil { return try await sqlite.createLast(record) }
            if let luid = record.luid, let macId = idPersistence.mac(for: luid) {
                return try await sqlite.createLast(record.with(macId: macId))
            }
            assertionFailure(); return false
        } catch { throw (error) }
    }

    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        do {
            if record.macId != nil { return try await sqlite.updateLast(record) }
            if let luid = record.luid, let macId = idPersistence.mac(for: luid) {
                return try await sqlite.updateLast(record.with(macId: macId))
            }
            assertionFailure(); return false
        } catch { throw (error) }
    }

    func deleteLast(_ ruuviTagId: String) async throws -> Bool {
        do { _ = try await sqlite.deleteLatest(ruuviTagId); return true } catch { throw (error) }
    }

    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool {
        do {
            let sqliteRecords = records.filter { $0.macId != nil }
            _ = try await sqlite.create(sqliteRecords)
            return true
        } catch { throw (error) }
    }

    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool {
        do { _ = try await sqlite.deleteAllRecords(ruuviTagId); return true } catch { throw (error) }
    }

    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool {
        do { _ = try await sqlite.deleteAllRecords(ruuviTagId, before: date); return true } catch { throw (error) }
    }

    @discardableResult
    func cleanupDBSpace() async throws -> Bool {
        do { _ = try await sqlite.cleanupDBSpace(); return true } catch { throw (error) }
    }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        guard ruuviTag.macId != nil else { assertionFailure(); throw (NSError(domain: "invalid", code: -1)) }
        do { return try await sqlite.updateOffsetCorrection(type: type, with: value, of: ruuviTag, lastOriginalRecord: record) } catch { throw (error) }
    }

    // MARK: - Queued cloud requests

    func createQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws -> Bool {
        do { return try await sqlite.createQueuedRequest(request) } catch { throw (error) }
    }

    func deleteQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws -> Bool {
        do { return try await sqlite.deleteQueuedRequest(request) } catch { throw (error) }
    }

    func deleteQueuedRequests() async throws -> Bool {
        do { return try await sqlite.deleteQueuedRequests() } catch { throw (error) }
    }

    // MARK: - Subscription
    func save(
        subscription: CloudSensorSubscription
    ) async throws -> CloudSensorSubscription {
        do { return try await sqlite.save(subscription: subscription) } catch { throw (error) }
    }
    

    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws -> CloudSensorSubscription? {
        do { return try await sqlite.readSensorSubscriptionSettings(ruuviTag) } catch { throw (error) }
    }
}
