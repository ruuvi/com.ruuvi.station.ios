import Foundation
import RuuviOntology
import RuuviStorage

final class MigrationStorage: RuuviStorage {
    let base: RuuviStorage
    var failReadAll = false
    var failLatest = false
    var failSettings = false
    var readAllCount = 0
    var beforeReadAll: (() async -> Void)?
    init(_ base: RuuviStorage) { self.base = base }
    func read(
        _ id: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        return try await base.read(id, after: date, with: interval)
    }
    func readDownsampled(
        _ id: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        return try await base.readDownsampled(id, after: date, with: intervalMinutes, pick: points)
    }
    func readOne(_ id: String) async throws(RuuviStorageError) -> AnyRuuviTagSensor {
        return try await base.readOne(id)
    }
    func readAll(_ id: String) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        return try await base.readAll(id)
    }
    func readAll(_ id: String, with interval: TimeInterval) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        return try await base.readAll(id, with: interval)
    }
    func readAll(_ id: String, after date: Date) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        return try await base.readAll(id, after: date)
    }
    func readAll() async throws(RuuviStorageError) -> [AnyRuuviTagSensor] {
        readAllCount += 1
        await beforeReadAll?()
        if failReadAll { throw .ruuviPersistence(.failedToFindRuuviTag) }
        return try await base.readAll()
    }
    func readLast(_ id: String, from: TimeInterval) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        return try await base.readLast(id, from: from)
    }
    func readLast(_ ruuviTag: RuuviTagSensor) async throws(RuuviStorageError) -> RuuviTagSensorRecord? {
        return try await base.readLast(ruuviTag)
    }
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws(RuuviStorageError) -> RuuviTagSensorRecord? {
        if failLatest { throw .ruuviPersistence(.failedToFindRuuviTag) }
        return try await base.readLatest(ruuviTag)
    }
    func getStoredTagsCount() async throws(RuuviStorageError) -> Int {
        return try await base.getStoredTagsCount()
    }
    func getClaimedTagsCount() async throws(RuuviStorageError) -> Int {
        return try await base.getClaimedTagsCount()
    }
    func getOfflineTagsCount() async throws(RuuviStorageError) -> Int {
        return try await base.getOfflineTagsCount()
    }
    func getStoredMeasurementsCount() async throws(RuuviStorageError) -> Int {
        return try await base.getStoredMeasurementsCount()
    }
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws(RuuviStorageError) -> SensorSettings? {
        if failSettings { throw .ruuviPersistence(.failedToFindRuuviTag) }
        return try await base.readSensorSettings(ruuviTag)
    }
    func readUserSettings() async throws(RuuviStorageError) -> [RuuviUserSetting] {
        return try await base.readUserSettings()
    }
    func readUserSetting(
        for key: String
    ) async throws(RuuviStorageError) -> RuuviUserSetting? {
        return try await base.readUserSetting(for: key)
    }
    func save(
        userSetting: RuuviUserSetting
    ) async throws(RuuviStorageError) -> RuuviUserSetting {
        return try await base.save(userSetting: userSetting)
    }
    func save(
        userSettings: [RuuviUserSetting]
    ) async throws(RuuviStorageError) -> [RuuviUserSetting] {
        return try await base.save(userSettings: userSettings)
    }
    func readQueuedRequests() async throws(RuuviStorageError) -> [RuuviCloudQueuedRequest] {
        return try await base.readQueuedRequests()
    }
    func readQueuedRequests(
        for key: String
    ) async throws(RuuviStorageError) -> [RuuviCloudQueuedRequest] {
        return try await base.readQueuedRequests(for: key)
    }
    func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) async throws(RuuviStorageError) -> [RuuviCloudQueuedRequest] {
        return try await base.readQueuedRequests(for: type)
    }
}
