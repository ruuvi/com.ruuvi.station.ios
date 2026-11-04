#if SWIFT_PACKAGE
    import RuuviStorage
    import RuuviCloud
    import RuuviPool
    import RuuviLocal
    import RuuviRepository
    import RuuviCore
#endif
import Foundation
import RuuviOntology

public protocol RuuviServiceOffsetCalibration {
    @discardableResult
    func set(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws(RuuviServiceError) -> SensorSettings
}

public extension RuuviServiceOffsetCalibration {
    @discardableResult
    func set(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor
    ) async throws(RuuviServiceError) -> SensorSettings {
        try await set(
            offset: offset,
            of: type,
            for: sensor,
            lastOriginalRecord: nil
        )
    }
}
