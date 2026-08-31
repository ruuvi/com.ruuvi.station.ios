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
        let timestamp = Date(timeIntervalSince1970: TimeInterval(Int(Date().timeIntervalSince1970)))
        if sensor.isCloud {
            updateOnCloud(offset: offset, of: type, for: sensor, timestamp: timestamp).on()
        }
        pool.updateOffsetCorrection(
            type: type,
            with: offset,
            of: sensor,
            lastOriginalRecord: record,
            lastUpdated: timestamp
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
        for sensor: RuuviTagSensor,
        timestamp: Date
    ) -> Future<AnyRuuviTagSensor, RuuviCloudError> {
        let setting: RuuviCloudApiSetting
        let value: Double
        switch type {
        case .temperature:
            setting = .sensorOffsetTemperature
            value = offset ?? 0
        case .humidity:
            setting = .sensorOffsetHumidity
            value = (offset ?? 0) * 100 // fraction locally, % on cloud
        case .pressure:
            setting = .sensorOffsetPressure
            value = (offset ?? 0) * 100 // hPa locally, Pa on cloud
        }
        return cloud.updateSensorSettings(
            for: sensor,
            types: [setting.rawValue],
            values: [String(value)],
            timestamp: Int(timestamp.timeIntervalSince1970)
        )
    }
}
