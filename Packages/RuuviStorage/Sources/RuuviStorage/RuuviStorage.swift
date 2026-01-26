import Foundation
import RuuviOntology
import RuuviPersistence

public protocol RuuviStorage: Sendable {
    func read(
        _ id: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord]
    func readDownsampled(
        _ id: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws -> [RuuviTagSensorRecord]
    func readOne(_ id: String) async throws -> AnyRuuviTagSensor
    func readAll(_ id: String) async throws -> [RuuviTagSensorRecord]
    func readAll(_ id: String, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord]
    func readAll(_ id: String, after date: Date) async throws -> [RuuviTagSensorRecord]
    func readAll() async throws -> [AnyRuuviTagSensor]
    func readLast(_ id: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord]
    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord?
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord?
    func getStoredTagsCount() async throws -> Int
    func getClaimedTagsCount() async throws -> Int
    func getOfflineTagsCount() async throws -> Int
    func getStoredMeasurementsCount() async throws -> Int
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings?

    // MARK: - Queued cloud requests

    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest]
    func readQueuedRequests(
        for key: String
    ) async throws -> [RuuviCloudQueuedRequest]
    func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) async throws -> [RuuviCloudQueuedRequest]
}

public protocol RuuviStorageFactory {
    func create(sqlite: RuuviPersistence) -> RuuviStorage
}
