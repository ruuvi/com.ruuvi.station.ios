import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceOwnership {
    @discardableResult
    func claim(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError>

    @discardableResult
    func unclaim(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError> 
}
