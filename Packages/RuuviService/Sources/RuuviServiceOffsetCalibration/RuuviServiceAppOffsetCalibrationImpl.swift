import Foundation
import Future
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
    ) -> Future<SensorSettings, RuuviServiceError> {
        let promise = Promise<SensorSettings, RuuviServiceError>()
        if sensor.isCloud {
            updateOnCloud(offset: offset, of: type, for: sensor).on()
        }
        pool.updateOffsetCorrection(
            type: type,
            with: offset,
            of: sensor,
            lastOriginalRecord: record
        ).on(success: { settings in
            promise.succeed(value: settings)
        }, failure: { error in
            promise.fail(error: .ruuviPool(error))
        })
        return promise.future
    }

    private func updateOnCloud(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensor, RuuviCloudError> {
        let cloudUpdate: Future<AnyRuuviTagSensor, RuuviCloudError> = switch type {
        case .temperature:
            cloud.update(
                temperatureOffset: offset ?? 0,
                humidityOffset: nil,
                pressureOffset: nil,
                for: sensor
            )
        case .humidity:
            cloud.update(
                temperatureOffset: nil,
                humidityOffset: (offset ?? 0) * 100, // fraction locally, % on cloud
                pressureOffset: nil,
                for: sensor
            )
        case .pressure:
            cloud.update(
                temperatureOffset: nil,
                humidityOffset: nil,
                pressureOffset: (offset ?? 0) * 100, // hPA locally, Pa on cloud
                for: sensor
            )
        }
        return cloudUpdate
    }
}
