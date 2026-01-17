import Foundation
import Future
import RuuviOntology

public protocol RuuviPersistence {
    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError>
    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError>
    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError>
    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RuuviPersistenceError>
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RuuviPersistenceError>
    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPersistenceError>
    func createLast(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPersistenceError>
    func updateLast(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPersistenceError>
    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RuuviPersistenceError>
    func readAll() -> Future<[AnyRuuviTagSensor], RuuviPersistenceError>
    func readAll(_ ruuviTagId: String) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError>
    func readAll(
        _ ruuviTagId: String,
        with interval: TimeInterval
    ) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError>
    func readAll(_ ruuviTagId: String, after date: Date) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError>
    func readLast(_ ruuviTagId: String, from: TimeInterval) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError>
    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RuuviPersistenceError>
    func readLatest(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RuuviPersistenceError>
    func deleteLatest(_ ruuviTagId: String) -> Future<Bool, RuuviPersistenceError>
    func readOne(_ ruuviTagId: String) -> Future<AnyRuuviTagSensor, RuuviPersistenceError>
    func getStoredTagsCount() -> Future<Int, RuuviPersistenceError>
    func getStoredMeasurementsCount() -> Future<Int, RuuviPersistenceError>

    func read(
        _ ruuviTagId: String,
        after date: Date,
        with interval: TimeInterval
    ) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError>

    func readDownsampled(
        _ ruuviTagId: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError>

    func readSensorSettings(
        _ ruuviTag: RuuviTagSensor
    ) -> Future<SensorSettings?, RuuviPersistenceError>

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) -> Future<SensorSettings, RuuviPersistenceError>

    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?
    ) -> Future<SensorSettings, RuuviPersistenceError>

    func deleteOffsetCorrection(
        ruuviTag: RuuviTagSensor
    ) -> Future<Bool, RuuviPersistenceError>

    func deleteSensorSettings(
        _ ruuviTag: RuuviTagSensor
    ) -> Future<Bool, RuuviPersistenceError>

    func save(
        sensorSettings: SensorSettings
    ) -> Future<SensorSettings, RuuviPersistenceError>

    func cleanupDBSpace() -> Future<Bool, RuuviPersistenceError>

    // MARK: - Queued cloud requests

    @discardableResult
    func readQueuedRequests() -> Future<[RuuviCloudQueuedRequest], RuuviPersistenceError>

    @discardableResult
    func readQueuedRequests(
        for key: String
    ) -> Future<[RuuviCloudQueuedRequest], RuuviPersistenceError>

    @discardableResult
    func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) -> Future<[RuuviCloudQueuedRequest], RuuviPersistenceError>

    @discardableResult
    func createQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) -> Future<Bool, RuuviPersistenceError>

    @discardableResult
    func deleteQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) -> Future<Bool, RuuviPersistenceError>

    @discardableResult
    func deleteQueuedRequests() -> Future<Bool, RuuviPersistenceError>

    // MARK: - Subscription
    func save(
        subscription: CloudSensorSubscription
    ) -> Future<CloudSensorSubscription, RuuviPersistenceError>

    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) -> Future<CloudSensorSubscription?, RuuviPersistenceError>
}
