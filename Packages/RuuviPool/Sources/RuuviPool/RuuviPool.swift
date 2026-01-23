import Foundation
import RuuviOntology

public protocol RuuviPool {
    // entities
    @discardableResult
    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool
    @discardableResult
    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool
    @discardableResult
    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool
    @discardableResult
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool

    // records
    @discardableResult
    func create(_ record: RuuviTagSensorRecord) async throws -> Bool
    @discardableResult
    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool
    @discardableResult
    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool
    @discardableResult
    func deleteLast(_ ruuviTagId: String) async throws -> Bool
    @discardableResult
    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool
    @discardableResult
    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool
    @discardableResult
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool

    @discardableResult
    func cleanupDBSpace() async throws -> Bool

    // offset calibration
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

    // MARK: - Queued cloud requests

    @discardableResult
    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool
    @discardableResult
    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool
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

public extension RuuviPool {
    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor
    ) async throws -> SensorSettings {
        try await updateOffsetCorrection(
            type: type,
            with: value,
            of: ruuviTag,
            lastOriginalRecord: nil
        )
    }
}
