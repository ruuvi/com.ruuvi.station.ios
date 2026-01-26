import Foundation
import RuuviOntology

public protocol RuuviPersistence: Sendable {
    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool
    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool
    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool
    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool
    func create(_ record: RuuviTagSensorRecord) async throws -> Bool
    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool
    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool
    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool
    func readAll() async throws -> [AnyRuuviTagSensor]
    func readAll(_ ruuviTagId: String) async throws -> [RuuviTagSensorRecord]
    func readAll(
        _ ruuviTagId: String,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord]
    func readAll(_ ruuviTagId: String, after date: Date) async throws -> [RuuviTagSensorRecord]
    func readLast(_ ruuviTagId: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord]
    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord?
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord?
    func deleteLatest(_ ruuviTagId: String) async throws -> Bool
    func readOne(_ ruuviTagId: String) async throws -> AnyRuuviTagSensor
    func getStoredTagsCount() async throws -> Int
    func getStoredMeasurementsCount() async throws -> Int

    func read(
        _ ruuviTagId: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord]

    func readDownsampled(
        _ ruuviTagId: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws -> [RuuviTagSensorRecord]

    func readSensorSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws -> SensorSettings?

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings

    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?
    ) async throws -> SensorSettings

    func deleteOffsetCorrection(
        ruuviTag: RuuviTagSensor
    ) async throws -> Bool

    func deleteSensorSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws -> Bool

    func save(
        sensorSettings: SensorSettings
    ) async throws -> SensorSettings

    func cleanupDBSpace() async throws -> Bool

    // MARK: - Queued cloud requests

    @discardableResult
    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest]

    @discardableResult
    func readQueuedRequests(
        for key: String
    ) async throws -> [RuuviCloudQueuedRequest]

    @discardableResult
    func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) async throws -> [RuuviCloudQueuedRequest]

    @discardableResult
    func createQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws -> Bool

    @discardableResult
    func deleteQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws -> Bool

    @discardableResult
    func deleteQueuedRequests() async throws -> Bool

    // MARK: - Subscription
    func save(
        subscription: CloudSensorSubscription
    ) async throws -> CloudSensorSubscription

    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws -> CloudSensorSubscription?
}
