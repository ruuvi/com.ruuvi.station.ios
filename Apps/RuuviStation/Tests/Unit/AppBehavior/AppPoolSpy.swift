import Foundation
import RuuviOntology
import RuuviPool

@MainActor final class AppPoolSpy: RuuviPool {
    var subscriptions = [String: CloudSensorSubscription]()
    var subscriptionReads = [String]()
    var subscriptionFailure: RuuviPoolError?
    var beforeSubscription: (() async -> Void)?
    func create(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func update(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func delete(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func create(_ record: RuuviTagSensorRecord) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func createLast(_ record: RuuviTagSensorRecord) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func updateLast(_ record: RuuviTagSensorRecord) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func deleteLast(_ ruuviTagId: String) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
    }
    func create(_ records: [RuuviTagSensorRecord]) async throws(RuuviPoolError) -> Bool {
        throw .ruuviPersistence(.failedToFindRuuviTag)
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
        throw .ruuviPersistence(.failedToFindRuuviTag)
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
