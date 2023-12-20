import BTKit
import Humidity
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import UIKit

class OffsetCorrectionViewModel {
    var type: OffsetCorrectionType = .temperature

    var originalValue: Observable<Double?> = .init()
    var updateAt: Observable<Date?> = .init()
    var offsetCorrectionValue: Observable<Double?> = .init()
    var offsetCorrectionDate: Observable<Date?> = .init()
    var correctedValue: Observable<Double?> = .init()

    let temperatureUnit: Observable<TemperatureUnit?> = .init()
    let humidityUnit: Observable<HumidityUnit?> = .init()
    let pressureUnit: Observable<UnitPressure?> = .init()

    var title: String {
        switch type {
        case .humidity:
            RuuviLocalization.OffsetCorrection.Humidity.title
        case .pressure:
            RuuviLocalization.OffsetCorrection.Pressure.title
        default:
            RuuviLocalization.OffsetCorrection.Temperature.title
        }
    }

    var hasOffsetValue: Observable<Bool?> = .init(false)

    init() {
        type = .pressure
        hasOffsetValue.value = false
    }

    convenience init(
        type: OffsetCorrectionType,
        sensorSettings: SensorSettings
    ) {
        self.init()
        self.type = type
        update(sensorSettings: sensorSettings)
    }

    func update(ruuviTagRecord: RuuviTagSensorRecord) {
        switch type {
        case .temperature:
            if let value = ruuviTagRecord.temperature?.value {
                originalValue.value = value - ruuviTagRecord.temperatureOffset
                correctedValue.value = value
            }
        case .humidity:
            if let value = ruuviTagRecord.humidity?.value {
                originalValue.value = value - ruuviTagRecord.humidityOffset
                correctedValue.value = value
            }
        case .pressure:
            if let value = ruuviTagRecord.pressure?.value {
                originalValue.value = value - ruuviTagRecord.pressureOffset
                correctedValue.value = value
            }
        }
        updateAt.value = ruuviTagRecord.date
    }

    func update(sensorSettings: SensorSettings) {
        switch type {
        case .temperature:
            offsetCorrectionValue.value = sensorSettings.temperatureOffset
            offsetCorrectionDate.value = sensorSettings.temperatureOffsetDate
        case .humidity:
            offsetCorrectionValue.value = sensorSettings.humidityOffset
            offsetCorrectionDate.value = sensorSettings.humidityOffsetDate
        case .pressure:
            offsetCorrectionValue.value = sensorSettings.pressureOffset
            offsetCorrectionDate.value = sensorSettings.pressureOffsetDate
        }

        if let value = offsetCorrectionValue.value, value != 0 {
            hasOffsetValue.value = true
        } else {
            hasOffsetValue.value = false
        }
    }
}
