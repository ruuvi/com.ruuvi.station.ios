import Foundation
import RuuviOntology

public protocol RuuviServiceSensorRecords {
    @discardableResult
    func clear(for sensor: RuuviTagSensor) async throws
}
