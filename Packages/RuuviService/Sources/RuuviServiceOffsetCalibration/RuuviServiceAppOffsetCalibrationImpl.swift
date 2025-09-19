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
        if sensor.isCloud {
            Task { [cloud] in
                _ = try? await updateOnCloud(offset: offset, of: type, for: sensor)
            }
        }
        do {
            return try await pool.updateOffsetCorrection(
                type: type,
                with: offset,
                of: sensor,
                lastOriginalRecord: record
            )
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        } catch { throw error }
    }

    private func updateOnCloud(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor {
        switch type {
        case .temperature:
            return try await cloud.update(
                temperatureOffset: offset ?? 0,
                humidityOffset: nil,
                pressureOffset: nil,
                for: sensor
            )
        case .humidity:
            return try await cloud.update(
                temperatureOffset: nil,
                humidityOffset: (offset ?? 0) * 100,
                pressureOffset: nil,
                for: sensor
            )
        case .pressure:
            return try await cloud.update(
                temperatureOffset: nil,
                humidityOffset: nil,
                pressureOffset: (offset ?? 0) * 100,
                for: sensor
            )
        }
    }
}
