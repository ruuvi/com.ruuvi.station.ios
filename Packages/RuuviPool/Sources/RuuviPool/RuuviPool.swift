import Foundation
import Future
import RuuviOntology

public protocol RuuviPool {
    // entities
    @discardableResult
    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError>

    // records
    @discardableResult
    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func createLast(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func updateLast(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func deleteLast(_ ruuviTagId: String) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RuuviPoolError>

    @discardableResult
    func cleanupDBSpace() -> Future<Bool, RuuviPoolError>

    // offset calibration
    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) -> Future<SensorSettings, RuuviPoolError>
    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?
    ) -> Future<SensorSettings, RuuviPoolError>

    // MARK: - Queued cloud requests

    @discardableResult
    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func deleteQueuedRequests() -> Future<Bool, RuuviPoolError>

    // MARK: - Subscription
    func save(
        subscription: CloudSensorSubscription
    ) -> Future<CloudSensorSubscription, RuuviPoolError>

    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) -> Future<CloudSensorSubscription?, RuuviPoolError>
}

public extension RuuviPool {
    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor
    ) -> Future<SensorSettings, RuuviPoolError> {
        updateOffsetCorrection(
            type: type,
            with: value,
            of: ruuviTag,
            lastOriginalRecord: nil
        )
    }
}
