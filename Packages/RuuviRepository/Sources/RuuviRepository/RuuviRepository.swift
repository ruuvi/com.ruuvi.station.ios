import Foundation
import RuuviOntology

// MIGRATE: Phase 4 converts the coordinator layer to async/await.
public protocol RuuviRepository {
    @discardableResult
    func create(
        record: RuuviTagSensorRecord,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensorRecord

    @discardableResult
    func create(
        records: [RuuviTagSensorRecord],
        for sensor: RuuviTagSensor
    ) async throws -> [AnyRuuviTagSensorRecord]
}
