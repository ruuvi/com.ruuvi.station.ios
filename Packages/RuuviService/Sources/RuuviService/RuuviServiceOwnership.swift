import Foundation
import Future
import RuuviCloud
import RuuviOntology

public protocol RuuviServiceOwnership {
    @discardableResult
    func add(
        sensor: RuuviTagSensor,
        record: RuuviTagSensorRecord
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError>

    @discardableResult
    func remove(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError>

    @discardableResult
    func claim(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError>

    @discardableResult
    func contest(sensor: RuuviTagSensor, secret: String) -> Future<AnyRuuviTagSensor, RuuviServiceError>

    @discardableResult
    func unclaim(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError>

    @discardableResult
    func share(macId: MACIdentifier, with email: String) -> Future<ShareSensorResponse, RuuviServiceError>

    @discardableResult
    func unshare(macId: MACIdentifier, with email: String?) -> Future<MACIdentifier, RuuviServiceError>

    @discardableResult
    func loadShared(for sensor: RuuviTagSensor) -> Future<Set<AnyShareableSensor>, RuuviServiceError>

    @discardableResult
    func checkOwner(macId: MACIdentifier) -> Future<(String?, String?), RuuviServiceError>

    @discardableResult
    func updateShareable(for sensor: RuuviTagSensor) -> Future<Bool, RuuviServiceError>
}
