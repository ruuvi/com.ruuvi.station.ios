#if SWIFT_PACKAGE
    import RuuviStorage
#endif
import Foundation
import RuuviOntology
import RuuviPersistence

final class RuuviStorageCoordinator: RuuviStorage {
    private let sqlite: RuuviPersistence

    init(sqlite: RuuviPersistence) {
        self.sqlite = sqlite
    }

    func readOne(_ ruuviTagId: String) async throws(RuuviStorageError) -> AnyRuuviTagSensor {
        do {
            return try await sqlite.readOne(ruuviTagId)
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func readAll(_ ruuviTagId: String) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        do {
            return try await sqlite.readAll(ruuviTagId)
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func readAll() async throws(RuuviStorageError) -> [AnyRuuviTagSensor] {
        do {
            return try await sqlite.readAll()
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func readAll(_ id: String, after date: Date) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        do {
            return try await sqlite.readAll(id, after: date)
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func read(
        _ id: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        do {
            return try await sqlite.read(id, after: date, with: interval)
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func readDownsampled(
        _ id: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        do {
            return try await sqlite.readDownsampled(
                id,
                after: date,
                with: intervalMinutes,
                pick: points
            )
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func readAll(
        _ id: String,
        with interval: TimeInterval
    ) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        do {
            return try await sqlite.readAll(id, with: interval)
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func readLast(_ id: String, from: TimeInterval) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        do {
            return try await sqlite.readLast(id, from: from)
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func readLast(_ ruuviTag: RuuviTagSensor) async throws(RuuviStorageError) -> RuuviTagSensorRecord? {
        guard ruuviTag.macId != nil || ruuviTag.luid != nil else {
            throw .ruuviPersistence(.failedToFindRuuviTag)
        }
        do {
            return try await sqlite.readLast(ruuviTag)
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func readLatest(_ ruuviTag: RuuviTagSensor) async throws(RuuviStorageError) -> RuuviTagSensorRecord? {
        guard ruuviTag.macId != nil || ruuviTag.luid != nil else {
            throw .ruuviPersistence(.failedToFindRuuviTag)
        }
        do {
            return try await sqlite.readLatest(ruuviTag)
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func getStoredTagsCount() async throws(RuuviStorageError) -> Int {
        do {
            return try await sqlite.getStoredTagsCount()
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func getClaimedTagsCount() async throws(RuuviStorageError) -> Int {
        return try await readAll().filter { $0.isClaimed && $0.isOwner }.count
    }

    func getOfflineTagsCount() async throws(RuuviStorageError) -> Int {
        return try await readAll().filter { !$0.isCloud }.count
    }

    func getStoredMeasurementsCount() async throws(RuuviStorageError) -> Int {
        do {
            return try await sqlite.getStoredMeasurementsCount()
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws(RuuviStorageError) -> SensorSettings? {
        guard ruuviTag.macId != nil || ruuviTag.luid != nil else {
            throw .ruuviPersistence(.failedToFindRuuviTag)
        }
        do {
            return try await sqlite.readSensorSettings(ruuviTag)
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    // MARK: - Queued cloud requests

    func readQueuedRequests()
        async throws(RuuviStorageError) -> [RuuviCloudQueuedRequest]
    {
        do {
            return try await sqlite.readQueuedRequests()
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func readQueuedRequests(
        for key: String
    ) async throws(RuuviStorageError) -> [RuuviCloudQueuedRequest] {
        do {
            return try await sqlite.readQueuedRequests(for: key)
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) async throws(RuuviStorageError) -> [RuuviCloudQueuedRequest] {
        do {
            return try await sqlite.readQueuedRequests(for: type)
        } catch {
            throw .ruuviPersistence(error)
        }
    }
}

// MARK: - User settings

extension RuuviStorageCoordinator {
    func readUserSettings() async throws(RuuviStorageError) -> [RuuviUserSetting] {
        do {
            return try await sqlite.readUserSettings()
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func readUserSetting(
        for key: String
    ) async throws(RuuviStorageError) -> RuuviUserSetting? {
        do {
            return try await sqlite.readUserSetting(for: key)
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func save(
        userSetting: RuuviUserSetting
    ) async throws(RuuviStorageError) -> RuuviUserSetting {
        do {
            return try await sqlite.save(userSetting: userSetting)
        } catch {
            throw .ruuviPersistence(error)
        }
    }

    func save(
        userSettings: [RuuviUserSetting]
    ) async throws(RuuviStorageError) -> [RuuviUserSetting] {
        do {
            return try await sqlite.save(userSettings: userSettings)
        } catch {
            throw .ruuviPersistence(error)
        }
    }
}
