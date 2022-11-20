import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceOwnership {
    @discardableResult
    func add(
        sensor: RuuviTagSensor,
        record: RuuviTagSensorRecord
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError>

    @discardableResult
    func remove(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError>

    @discardableResult
    func claim(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError>

    @discardableResult
    func unclaim(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError>

    @discardableResult
    func share(macId: MACIdentifier, with email: String) -> Future<MACIdentifier, RuuviServiceError>

    @discardableResult
    func unshare(macId: MACIdentifier, with email: String?) -> Future<MACIdentifier, RuuviServiceError>

    @discardableResult
    func loadShared(for sensor: RuuviTagSensor) -> Future<Set<AnyShareableSensor>, RuuviServiceError>

    @discardableResult
    func checkOwner(macId: MACIdentifier) -> Future<String, RuuviServiceError>
}
