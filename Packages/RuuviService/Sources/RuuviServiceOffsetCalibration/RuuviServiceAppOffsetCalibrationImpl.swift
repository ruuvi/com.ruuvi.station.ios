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
    public func set(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        let updatedSensor = sensor.with(lastUpdated: Date())
        if sensor.isCloud {
            updateOnCloud(offset: offset, of: type, for: sensor)
        }
        return try await RuuviServiceError.perform {
            let settings = try await self.pool.updateOffsetCorrection(
                type: type,
                with: offset,
                of: sensor,
                lastOriginalRecord: record
            )
            _ = try? await self.pool.update(updatedSensor)
            return settings
        }
    }

    private func updateOnCloud(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor
    ) {
        switch type {
        case .temperature:
            Task {
                _ = try? await cloud.update(
                    temperatureOffset: offset ?? 0,
                    humidityOffset: nil,
                    pressureOffset: nil,
                    for: sensor
                )
            }
        case .humidity:
            Task {
                _ = try? await cloud.update(
                    temperatureOffset: nil,
                    humidityOffset: (offset ?? 0) * 100, // fraction locally, % on cloud
                    pressureOffset: nil,
                    for: sensor
                )
            }
        case .pressure:
            Task {
                _ = try? await cloud.update(
                    temperatureOffset: nil,
                    humidityOffset: nil,
                    pressureOffset: (offset ?? 0) * 100, // hPA locally, Pa on cloud
                    for: sensor
                )
            }
        }
    }
}
