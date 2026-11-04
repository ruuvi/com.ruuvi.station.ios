#if SWIFT_PACKAGE
    import RuuviStorage
    import RuuviPool
    import RuuviLocal
    import RuuviRepository
    import RuuviCore
#endif
import Foundation
import RuuviCloud
import RuuviOntology

public protocol RuuviServiceOwnership {
    @discardableResult
    func add(
        sensor: RuuviTagSensor,
        record: RuuviTagSensorRecord?
    ) async throws(RuuviServiceError) -> AnyRuuviTagSensor

    @discardableResult
    func remove(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) async throws(RuuviServiceError) -> AnyRuuviTagSensor

    @discardableResult
    func claim(sensor: RuuviTagSensor) async throws(RuuviServiceError) -> AnyRuuviTagSensor

    @discardableResult
    func contest(sensor: RuuviTagSensor, secret: String) async throws(RuuviServiceError) -> AnyRuuviTagSensor

    @discardableResult
    func unclaim(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) async throws(RuuviServiceError) -> AnyRuuviTagSensor

    @discardableResult
    func share(macId: MACIdentifier, with email: String) async throws(RuuviServiceError) -> ShareSensorResponse

    @discardableResult
    func unshare(macId: MACIdentifier, with email: String?) async throws(RuuviServiceError) -> MACIdentifier

    @discardableResult
    func loadShared(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> Set<AnyShareableSensor>

    @discardableResult
    func checkOwner(macId: MACIdentifier) async throws(RuuviServiceError) -> (String?, String?)

    @discardableResult
    func updateShareable(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> Bool
}
