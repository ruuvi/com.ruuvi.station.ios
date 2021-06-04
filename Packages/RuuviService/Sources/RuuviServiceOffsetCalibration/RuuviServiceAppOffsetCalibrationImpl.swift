import Foundation
import Future
import RuuviOntology
import RuuviCloud
import RuuviPool

final class RuuviServiceAppOffsetCalibrationImpl: RuuviServiceOffsetCalibration {
    private let cloud: RuuviCloud
    private var pool: RuuviPool

    init(
        cloud: RuuviCloud,
        pool: RuuviPool
    ) {
        self.cloud = cloud
        self.pool = pool
    }

    @discardableResult
    func set(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) -> Future<SensorSettings, RuuviServiceError> {
        let promise = Promise<SensorSettings, RuuviServiceError>()
        if sensor.isOwner {
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
        let cloudUpdate: Future<AnyRuuviTagSensor, RuuviCloudError>
        switch type {
        case .temperature:
            cloudUpdate = cloud.update(
                temperatureOffset: offset,
                humidityOffset: nil,
                pressureOffset: nil,
                for: sensor
            )
        case .humidity:
            cloudUpdate = cloud.update(
                temperatureOffset: nil,
                humidityOffset: offset,
                pressureOffset: nil,
                for: sensor
            )
        case .pressure:
            cloudUpdate = cloud.update(
                temperatureOffset: nil,
                humidityOffset: nil,
                pressureOffset: offset,
                for: sensor
            )
        }
        return cloudUpdate
    }
}
