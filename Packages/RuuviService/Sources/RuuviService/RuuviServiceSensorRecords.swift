import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceSensorRecords {
    @discardableResult
    func clear(for sensor: RuuviTagSensor) -> Future<Void, RuuviServiceError>
}
