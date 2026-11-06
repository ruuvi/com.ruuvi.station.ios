import Foundation
import RuuviOntology
import RuuviStorage

@MainActor final class AppTestStorage: RuuviStorage {
    var settingsBySensor: [String: SensorSettings]?
    var oneSensors: [String: AnyRuuviTagSensor]?
    var oneReads = [String]()
    var beforeReadOne: (() async -> Void)?
    let base: RuuviStorage
    var sensorsOverride: [AnyRuuviTagSensor]?
    var records: [RuuviTagSensorRecord] = []
    var downsampled: [RuuviTagSensorRecord] = []
    var recent: [RuuviTagSensorRecord] = []
    var readCount = 0
    var downsampleCount = 0
    var latestCount = 0
    var requestedPoints: Double?
    var requestedFrom: Date?
    var failReadAll = false
    var failLatest = false
    var useLatestOverride = false
    var latestOverride: RuuviTagSensorRecord?
    var failSettings = false
    var readAllCount = 0
    var beforeReadAll: (() async -> Void)?
    var beforeRead: (() async -> Void)?
    var beforeLatest: (() async -> Void)?
    var failure: RuuviStorageError?
    init(_ base: RuuviStorage) { self.base = base }
    func read(
        _ id: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        readCount += 1
        requestedFrom = date
        let result = records
        await beforeRead?()
        if let failure { throw failure }
        return result
    }
    func readDownsampled(
        _ id: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        downsampleCount += 1
        requestedPoints = points
        if let failure { throw failure }
        return downsampled
    }
    func readOne(_ id: String) async throws(RuuviStorageError) -> AnyRuuviTagSensor {
        oneReads.append(id)
        let captured = oneSensors
        await beforeReadOne?()
        if let captured {
            guard let sensor = captured[id] else { throw .ruuviPersistence(.failedToFindRuuviTag) }
            return sensor
        }
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
        let result = sensorsOverride
        await beforeReadAll?()
        if failReadAll { throw .ruuviPersistence(.failedToFindRuuviTag) }
        if let result { return result }
        return try await base.readAll()
    }
    func readLast(_ id: String, from: TimeInterval) async throws(RuuviStorageError) -> [RuuviTagSensorRecord] {
        latestCount += 1
        await beforeLatest?()
        if let failure { throw failure }
        return recent
    }
    func readLast(_ ruuviTag: RuuviTagSensor) async throws(RuuviStorageError) -> RuuviTagSensorRecord? {
        return try await base.readLast(ruuviTag)
    }
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws(RuuviStorageError) -> RuuviTagSensorRecord? {
        if useLatestOverride {
            let result = latestOverride
            await beforeLatest?()
            if failLatest { throw .ruuviPersistence(.failedToFindRuuviTag) }
            return result
        }
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
        if let settingsBySensor { return settingsBySensor[ruuviTag.id] }
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
