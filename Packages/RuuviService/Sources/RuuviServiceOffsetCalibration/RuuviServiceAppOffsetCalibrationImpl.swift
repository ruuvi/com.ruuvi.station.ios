#if SWIFT_PACKAGE
    import RuuviService
#endif
import Foundation
import RuuviCloud
import RuuviOntology
import RuuviPool

public final class RuuviServiceAppOffsetCalibrationImpl: RuuviServiceOffsetCalibration {
    private let cloud: RuuviCloud
    private var pool: RuuviPool

    public init(
        cloud: RuuviCloud,
        pool: RuuviPool
    ) {
        self.cloud = cloud
        self.pool = pool
    }

    @discardableResult
    @MainActor
    public func set(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws(RuuviServiceError) -> SensorSettings {
        let settings: SensorSettings
        do {
            settings = try await pool.updateOffsetCorrection(
                type: type, with: offset, of: sensor, lastOriginalRecord: record)
            _ = try await pool.update(sensor.with(lastUpdated: Date()))
        } catch { throw .ruuviPool(error) }
        if sensor.isCloud { _ = try? await updateOnCloud(offset: offset, of: type, for: sensor) }
        return settings
    }

    @MainActor
    private func updateOnCloud(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        return switch type {
        case .temperature:
            try await cloud.update(
                temperatureOffset: offset ?? 0,
                humidityOffset: nil,
                pressureOffset: nil,
                for: sensor
            )
        case .humidity:
            try await cloud.update(
                temperatureOffset: nil,
                humidityOffset: (offset ?? 0) * 100,  // fraction locally, % on cloud
                pressureOffset: nil,
                for: sensor
            )
        case .pressure:
            try await cloud.update(
                temperatureOffset: nil,
                humidityOffset: nil,
                pressureOffset: (offset ?? 0) * 100,  // hPA locally, Pa on cloud
                for: sensor
            )
        }
    }
}
