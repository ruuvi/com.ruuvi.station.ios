import Foundation
import RuuviCloud
import RuuviOntology

public protocol RuuviServiceOwnership {
    @discardableResult
    func add(
        sensor: RuuviTagSensor,
        record: RuuviTagSensorRecord
    ) async throws -> AnyRuuviTagSensor

    @discardableResult
    func remove(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) async throws -> AnyRuuviTagSensor

    @discardableResult
    func claim(sensor: RuuviTagSensor) async throws -> AnyRuuviTagSensor

    @discardableResult
    func contest(sensor: RuuviTagSensor, secret: String) async throws -> AnyRuuviTagSensor

    @discardableResult
    func unclaim(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) async throws -> AnyRuuviTagSensor

    @discardableResult
    func share(macId: MACIdentifier, with email: String) async throws -> ShareSensorResponse

    @discardableResult
    func unshare(macId: MACIdentifier, with email: String?) async throws -> MACIdentifier

    @discardableResult
    func loadShared(for sensor: RuuviTagSensor) async throws -> Set<AnyShareableSensor>

    @discardableResult
    func checkOwner(macId: MACIdentifier) async throws -> String?

    @discardableResult
    func updateShareable(for sensor: RuuviTagSensor) async throws -> Bool
}
