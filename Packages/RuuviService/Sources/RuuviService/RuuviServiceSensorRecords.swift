import Foundation
import RuuviOntology

public protocol RuuviServiceSensorRecords {
    func clear(for sensor: RuuviTagSensor) async throws
}
