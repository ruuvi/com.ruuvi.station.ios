import Foundation
import RuuviOntology
import RuuviPersistence

final class RuuviStorageCoordinator: RuuviStorage {
    private let sqlite: RuuviPersistence

    init(sqlite: RuuviPersistence) {
        self.sqlite = sqlite
    }

    func readOne(_ ruuviTagId: String) async throws -> AnyRuuviTagSensor {
        do { return try await sqlite.readOne(ruuviTagId) } catch { throw error }
    }

    func readAll(_ ruuviTagId: String) async throws -> [RuuviTagSensorRecord] {
        do { return try await sqlite.readAll(ruuviTagId) } catch { throw error }
    }

    func readAll() async throws -> [AnyRuuviTagSensor] {
        do { return try await sqlite.readAll().map(\ .any) } catch { throw error }
    }

    func readAll(_ id: String, after date: Date) async throws -> [RuuviTagSensorRecord] {
        do { return try await sqlite.readAll(id, after: date) } catch { throw error }
    }

    func read(
        _ id: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        do { return try await sqlite.read(id, after: date, with: interval) } catch { throw error }
    }

    func readDownsampled(
        _ id: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws -> [RuuviTagSensorRecord] {
        do { return try await sqlite.readDownsampled(id, after: date, with: intervalMinutes, pick: points) } catch { throw error }
    }

    func readAll(
        _ id: String,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        do { return try await sqlite.readAll(id, with: interval) } catch { throw error }
    }

    func readLast(_ id: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] {
        do { return try await sqlite.readLast(id, from: from) } catch { throw error }
    }

    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        guard ruuviTag.macId != nil else { assertionFailure(); return nil }
        do { return try await sqlite.readLast(ruuviTag) } catch { throw error }
    }

    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        guard ruuviTag.macId != nil else { assertionFailure(); return nil }
        do { return try await sqlite.readLatest(ruuviTag) } catch { throw error }
    }

    func getStoredTagsCount() async throws -> Int {
        do { return try await sqlite.getStoredTagsCount() } catch { throw error }
    }

    func getClaimedTagsCount() async throws -> Int {
        let tags = try await readAll()
        let claimedTags = tags.filter { $0.isClaimed && $0.isOwner }
        return claimedTags.count
    }

    func getOfflineTagsCount() async throws -> Int {
        let tags = try await readAll()
        return tags.filter { !$0.isCloud }.count
    }

    func getStoredMeasurementsCount() async throws -> Int {
        do { return try await sqlite.getStoredMeasurementsCount() } catch { throw error }
    }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        guard ruuviTag.macId != nil else { assertionFailure(); return nil }
        do { return try await sqlite.readSensorSettings(ruuviTag) } catch { throw error }
    }

    // MARK: - Queued cloud requests

    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] {
        do { return try await sqlite.readQueuedRequests() } catch { throw error  }
    }

    func readQueuedRequests(
        for key: String
    ) async throws -> [RuuviCloudQueuedRequest] {
        do { return try await sqlite.readQueuedRequests(for: key) } catch { throw error }
    }

    func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) async throws -> [RuuviCloudQueuedRequest] {
        do { return try await sqlite.readQueuedRequests(for: type) } catch { throw error }
    }
}
