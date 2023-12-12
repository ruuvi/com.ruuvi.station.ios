import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceOffsetCalibration {
    @discardableResult
    func set(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) -> Future<SensorSettings, RuuviServiceError>
}

public extension RuuviServiceOffsetCalibration {
    @discardableResult
    func set(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor
    ) -> Future<SensorSettings, RuuviServiceError> {
        set(
            offset: offset,
            of: type,
            for: sensor,
            lastOriginalRecord: nil
        )
    }
}
