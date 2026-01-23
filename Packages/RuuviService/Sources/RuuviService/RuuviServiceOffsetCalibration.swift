import Foundation
import RuuviOntology

public protocol RuuviServiceOffsetCalibration {
    @discardableResult
    func set(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings
}

public extension RuuviServiceOffsetCalibration {
    @discardableResult
    func set(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor
    ) async throws -> SensorSettings {
        try await set(
            offset: offset,
            of: type,
            for: sensor,
            lastOriginalRecord: nil
        )
    }
}
