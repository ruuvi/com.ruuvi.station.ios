import Foundation
import RuuviOntology
import RuuviPersistence

public protocol RuuviStorage {
    func read(
        _ id: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws(RuuviStorageError) -> [RuuviTagSensorRecord]
    func readDownsampled(
        _ id: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws(RuuviStorageError) -> [RuuviTagSensorRecord]
    func readOne(_ id: String) async throws(RuuviStorageError) -> AnyRuuviTagSensor
    func readAll(_ id: String) async throws(RuuviStorageError) -> [RuuviTagSensorRecord]
    func readAll(_ id: String, with interval: TimeInterval) async throws(RuuviStorageError) -> [RuuviTagSensorRecord]
    func readAll(_ id: String, after date: Date) async throws(RuuviStorageError) -> [RuuviTagSensorRecord]
    func readAll() async throws(RuuviStorageError) -> [AnyRuuviTagSensor]
    func readLast(_ id: String, from: TimeInterval) async throws(RuuviStorageError) -> [RuuviTagSensorRecord]
    func readLast(_ ruuviTag: RuuviTagSensor) async throws(RuuviStorageError) -> RuuviTagSensorRecord?
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws(RuuviStorageError) -> RuuviTagSensorRecord?
    func getStoredTagsCount() async throws(RuuviStorageError) -> Int
    func getClaimedTagsCount() async throws(RuuviStorageError) -> Int
    func getOfflineTagsCount() async throws(RuuviStorageError) -> Int
    func getStoredMeasurementsCount() async throws(RuuviStorageError) -> Int
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws(RuuviStorageError) -> SensorSettings?

    // MARK: - User settings

    func readUserSettings() async throws(RuuviStorageError) -> [RuuviUserSetting]
    func readUserSetting(
        for key: String
    ) async throws(RuuviStorageError) -> RuuviUserSetting?
    func save(
        userSetting: RuuviUserSetting
    ) async throws(RuuviStorageError) -> RuuviUserSetting
    func save(
        userSettings: [RuuviUserSetting]
    ) async throws(RuuviStorageError) -> [RuuviUserSetting]

    // MARK: - Queued cloud requests

    func readQueuedRequests() async throws(RuuviStorageError) -> [RuuviCloudQueuedRequest]
    func readQueuedRequests(
        for key: String
    ) async throws(RuuviStorageError) -> [RuuviCloudQueuedRequest]
    func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) async throws(RuuviStorageError) -> [RuuviCloudQueuedRequest]
}

public protocol RuuviStorageFactory {
    func create(sqlite: RuuviPersistence) -> RuuviStorage
}
