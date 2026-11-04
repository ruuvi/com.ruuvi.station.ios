#if SWIFT_PACKAGE
    import RuuviPersistence
    import RuuviLocal
#endif
import Foundation
import RuuviOntology

public protocol RuuviPool {
    // entities
    @discardableResult
    func create(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool
    @discardableResult
    func update(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool
    @discardableResult
    func delete(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool
    @discardableResult
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool

    // records
    @discardableResult
    func create(_ record: RuuviTagSensorRecord) async throws(RuuviPoolError) -> Bool
    @discardableResult
    func createLast(_ record: RuuviTagSensorRecord) async throws(RuuviPoolError) -> Bool
    @discardableResult
    func updateLast(_ record: RuuviTagSensorRecord) async throws(RuuviPoolError) -> Bool
    @discardableResult
    func deleteLast(_ ruuviTagId: String) async throws(RuuviPoolError) -> Bool
    @discardableResult
    func create(_ records: [RuuviTagSensorRecord]) async throws(RuuviPoolError) -> Bool
    @discardableResult
    func deleteAllRecords(_ ruuviTagId: String) async throws(RuuviPoolError) -> Bool
    @discardableResult
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws(RuuviPoolError) -> Bool

    @discardableResult
    func cleanupDBSpace() async throws(RuuviPoolError) -> Bool

    // offset calibration
    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws(RuuviPoolError) -> SensorSettings
    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) async throws(RuuviPoolError) -> SensorSettings
    func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws(RuuviPoolError) -> SensorSettings
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> SensorSettings?

    // MARK: - Queued cloud requests

    @discardableResult
    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws(RuuviPoolError) -> Bool
    @discardableResult
    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws(RuuviPoolError) -> Bool
    @discardableResult
    func deleteQueuedRequests() async throws(RuuviPoolError) -> Bool
    @discardableResult
    func deleteUserSettings() async throws(RuuviPoolError) -> Bool

    // MARK: - Subscription
    func save(
        subscription: CloudSensorSubscription
    ) async throws(RuuviPoolError) -> CloudSensorSubscription

    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws(RuuviPoolError) -> CloudSensorSubscription?
}

public extension RuuviPool {
    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor
    ) async throws(RuuviPoolError) -> SensorSettings {
        try await updateOffsetCorrection(
            type: type,
            with: value,
            of: ruuviTag,
            lastOriginalRecord: nil
        )
    }
}
