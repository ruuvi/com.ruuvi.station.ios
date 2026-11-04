#if SWIFT_PACKAGE
    import RuuviPool
    import RuuviStorage
#endif
import Foundation
import RuuviOntology

public protocol RuuviRepository {
    @discardableResult
    func create(
        record: RuuviTagSensorRecord,
        for sensor: RuuviTagSensor
    ) async throws(RuuviRepositoryError) -> AnyRuuviTagSensorRecord

    @discardableResult
    func create(
        records: [RuuviTagSensorRecord],
        for sensor: RuuviTagSensor
    ) async throws(RuuviRepositoryError) -> [AnyRuuviTagSensorRecord]
}
