import Foundation
import Future
import RuuviOntology

public protocol RuuviRepository {
    @discardableResult
    func create(
        record: RuuviTagSensorRecord,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensorRecord, RuuviRepositoryError>

    @discardableResult
    func create(
        records: [RuuviTagSensorRecord],
        for sensor: RuuviTagSensor
    ) -> Future<[AnyRuuviTagSensorRecord], RuuviRepositoryError>
}
