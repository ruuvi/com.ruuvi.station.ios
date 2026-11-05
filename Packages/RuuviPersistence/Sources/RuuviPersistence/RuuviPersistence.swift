#if SWIFT_PACKAGE
    import RuuviContext
#endif
import Foundation
import RuuviOntology

public protocol RuuviPersistence {
    func create(_ ruuviTag: RuuviTagSensor) async throws(RuuviPersistenceError) -> Bool
    func update(_ ruuviTag: RuuviTagSensor) async throws(RuuviPersistenceError) -> Bool
    /// Removes the sensor and its calibration atomically; a failure preserves both.
    func delete(_ ruuviTag: RuuviTagSensor) async throws(RuuviPersistenceError) -> Bool
    func deleteAllRecords(_ ruuviTagId: String) async throws(RuuviPersistenceError) -> Bool
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws(RuuviPersistenceError) -> Bool
    func create(_ record: RuuviTagSensorRecord) async throws(RuuviPersistenceError) -> Bool
    func createLast(_ record: RuuviTagSensorRecord) async throws(RuuviPersistenceError) -> Bool
    func updateLast(_ record: RuuviTagSensorRecord) async throws(RuuviPersistenceError) -> Bool
    func create(_ records: [RuuviTagSensorRecord]) async throws(RuuviPersistenceError) -> Bool
    func readAll() async throws(RuuviPersistenceError) -> [AnyRuuviTagSensor]
    func readAll(_ ruuviTagId: String) async throws(RuuviPersistenceError) -> [RuuviTagSensorRecord]
    func readAll(
        _ ruuviTagId: String,
        with interval: TimeInterval
    ) async throws(RuuviPersistenceError) -> [RuuviTagSensorRecord]
    func readAll(_ ruuviTagId: String, after date: Date) async throws(RuuviPersistenceError) -> [RuuviTagSensorRecord]
    func readLast(_ ruuviTagId: String, from: TimeInterval) async throws(RuuviPersistenceError)
        -> [RuuviTagSensorRecord]
    func readLast(_ ruuviTag: RuuviTagSensor) async throws(RuuviPersistenceError) -> RuuviTagSensorRecord?
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws(RuuviPersistenceError) -> RuuviTagSensorRecord?
    func deleteLatest(_ ruuviTagId: String) async throws(RuuviPersistenceError) -> Bool
    func readOne(_ ruuviTagId: String) async throws(RuuviPersistenceError) -> AnyRuuviTagSensor
    func getStoredTagsCount() async throws(RuuviPersistenceError) -> Int
    func getStoredMeasurementsCount() async throws(RuuviPersistenceError) -> Int

    func read(
        _ ruuviTagId: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws(RuuviPersistenceError) -> [RuuviTagSensorRecord]

    func readDownsampled(
        _ ruuviTagId: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws(RuuviPersistenceError) -> [RuuviTagSensorRecord]

    func readSensorSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws(RuuviPersistenceError) -> SensorSettings?

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws(RuuviPersistenceError) -> SensorSettings

    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) async throws(RuuviPersistenceError) -> SensorSettings

    func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws(RuuviPersistenceError) -> SensorSettings

    func deleteOffsetCorrection(
        ruuviTag: RuuviTagSensor
    ) async throws(RuuviPersistenceError) -> Bool

    func deleteSensorSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws(RuuviPersistenceError) -> Bool

    func save(
        sensorSettings: SensorSettings
    ) async throws(RuuviPersistenceError) -> SensorSettings

    // MARK: - User settings

    func readUserSettings() async throws(RuuviPersistenceError) -> [RuuviUserSetting]

    func readUserSetting(
        for key: String
    ) async throws(RuuviPersistenceError) -> RuuviUserSetting?

    func save(
        userSetting: RuuviUserSetting
    ) async throws(RuuviPersistenceError) -> RuuviUserSetting

    func save(
        userSettings: [RuuviUserSetting]
    ) async throws(RuuviPersistenceError) -> [RuuviUserSetting]

    func deleteUserSettings() async throws(RuuviPersistenceError) -> Bool

    func cleanupDBSpace() async throws(RuuviPersistenceError) -> Bool

    // MARK: - Queued cloud requests

    @discardableResult
    func readQueuedRequests() async throws(RuuviPersistenceError) -> [RuuviCloudQueuedRequest]

    @discardableResult
    func readQueuedRequests(
        for key: String
    ) async throws(RuuviPersistenceError) -> [RuuviCloudQueuedRequest]

    @discardableResult
    func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) async throws(RuuviPersistenceError) -> [RuuviCloudQueuedRequest]

    @discardableResult
    func createQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws(RuuviPersistenceError) -> Bool

    @discardableResult
    func deleteQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws(RuuviPersistenceError) -> Bool

    @discardableResult
    func deleteQueuedRequests() async throws(RuuviPersistenceError) -> Bool

    // MARK: - Subscription
    func save(
        subscription: CloudSensorSubscription
    ) async throws(RuuviPersistenceError) -> CloudSensorSubscription

    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws(RuuviPersistenceError) -> CloudSensorSubscription?
}
