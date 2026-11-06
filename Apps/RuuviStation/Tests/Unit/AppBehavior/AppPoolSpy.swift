import Foundation
import RuuviOntology
import RuuviPool

@MainActor final class AppPoolSpy: RuuviPool {
    var allowRecordWrites = false
    var recordFailure: RuuviPoolError?
    var createdBatches = [[AnyRuuviTagSensorRecord]]()
    var beforeCreateBatch: (() async -> Void)?
    var createdRecords = [AnyRuuviTagSensorRecord]()
    var createdLatest = [AnyRuuviTagSensorRecord]()
    var updatedLatest = [AnyRuuviTagSensorRecord]()
    var beforeCreateRecord: (() async -> Void)?
    var beforeCreateLatest: (() async -> Void)?
    var beforeUpdateLatest: (() async -> Void)?
    var sensorSettings = [String: SensorSettings]()
    var settingsReads = [String]()
    var beforeReadSettings: (() async -> Void)?
    var updatedSensors = [AnyRuuviTagSensor]()
    var allowSensorUpdates = false
    var beforeUpdate: (() async -> Void)?
    var subscriptions = [String: CloudSensorSubscription]()
    var subscriptionReads = [String]()
    var subscriptionFailure: RuuviPoolError?
    var beforeSubscription: (() async -> Void)?
    func create(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func update(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        updatedSensors.append(ruuviTag.any)
        await beforeUpdate?()
        guard allowSensorUpdates else { throw .ruuviPersistence(.failedToFindRuuviTag) }
        return true
    }
    func delete(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func create(_ record: RuuviTagSensorRecord) async throws(RuuviPoolError) -> Bool {
        guard allowRecordWrites else { throw .ruuviPersistence(.failedToFindRuuviTag) }
        createdRecords.append(record.any)
        await beforeCreateRecord?()
        if let recordFailure { throw recordFailure }
        return true
    }
    func createLast(_ record: RuuviTagSensorRecord) async throws(RuuviPoolError) -> Bool {
        guard allowRecordWrites else { throw .ruuviPersistence(.failedToFindRuuviTag) }
        createdLatest.append(record.any)
        await beforeCreateLatest?()
        if let recordFailure { throw recordFailure }
        return true
    }
    func updateLast(_ record: RuuviTagSensorRecord) async throws(RuuviPoolError) -> Bool {
        guard allowRecordWrites else { throw .ruuviPersistence(.failedToFindRuuviTag) }
        updatedLatest.append(record.any)
        await beforeUpdateLatest?()
        if let recordFailure { throw recordFailure }
        return true
    }
    func deleteLast(_ ruuviTagId: String) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func create(_ records: [RuuviTagSensorRecord]) async throws(RuuviPoolError) -> Bool {
        guard allowRecordWrites else { throw .ruuviPersistence(.failedToFindRuuviTag) }
        createdBatches.append(records.map(\.any))
        await beforeCreateBatch?()
        if let recordFailure { throw recordFailure }
        return true
    }
    func deleteAllRecords(_ ruuviTagId: String) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func cleanupDBSpace() async throws(RuuviPoolError) -> Bool { throw .ruuviPersistence(.failedToFindRuuviTag) }
    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws(RuuviPoolError) -> SensorSettings { throw .ruuviPersistence(.failedToFindRuuviTag) }
    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) async throws(RuuviPoolError) -> SensorSettings { throw .ruuviPersistence(.failedToFindRuuviTag) }
    func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws(RuuviPoolError) -> SensorSettings { throw .ruuviPersistence(.failedToFindRuuviTag) }
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> SensorSettings? {
        settingsReads.append(ruuviTag.id)
        let value = sensorSettings[ruuviTag.id]
        await beforeReadSettings?()
        return value
    }
    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func deleteQueuedRequests() async throws(RuuviPoolError) -> Bool { throw .ruuviPersistence(.failedToFindRuuviTag) }
    func deleteUserSettings() async throws(RuuviPoolError) -> Bool { throw .ruuviPersistence(.failedToFindRuuviTag) }
    func save(
        subscription: CloudSensorSubscription
    ) async throws(RuuviPoolError) -> CloudSensorSubscription { throw .ruuviPersistence(.failedToFindRuuviTag) }
    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws(RuuviPoolError) -> CloudSensorSubscription? {
        subscriptionReads.append(ruuviTag.id)
        let result = subscriptions[ruuviTag.id]
        await beforeSubscription?()
        if let subscriptionFailure { throw subscriptionFailure }
        return result
    }
}
