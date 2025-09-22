import Foundation
import RuuviOntology

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
