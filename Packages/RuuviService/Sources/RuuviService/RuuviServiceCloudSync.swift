import Foundation
import RuuviOntology

// MIGRATE: 7 declarations audited for async/await migration.
public protocol RuuviServiceCloudSync {
    @discardableResult
    func syncAll() async throws -> Set<AnyRuuviTagSensor>

    @discardableResult
    func sync(sensor: RuuviTagSensor) async throws -> [AnyRuuviTagSensorRecord]

    @discardableResult
    func syncAllHistory() async throws -> Bool

    @discardableResult
    func refreshLatestRecord() async throws -> Bool

    @discardableResult
    func syncAllRecords() async throws -> Bool

    @discardableResult
    func syncSettings() async throws -> RuuviCloudSettings

    @discardableResult
    func executePendingRequests() async throws -> Bool
}
