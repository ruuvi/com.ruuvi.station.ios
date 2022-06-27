import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceCloudSync {
    @discardableResult
    func syncAll() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError>

    @discardableResult
    func syncSensors() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError>

    @discardableResult
    func sync(sensor: RuuviTagSensor) -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError>

    @discardableResult
    func syncAllRecords(latestOnly: Bool) -> Future<Bool, RuuviServiceError>

    @discardableResult
    func syncSettings() -> Future<RuuviCloudSettings, RuuviServiceError>
}
