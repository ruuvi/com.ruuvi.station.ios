import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceCloudSync {
    @discardableResult
    func sync() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError>
    
    @discardableResult
    func sync(sensor: RuuviTagSensor) -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError>
}
