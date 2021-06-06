import UIKit
import BTKit
import Humidity
import RuuviOntology

class OffsetCorrectionViewModel {
    var type: OffsetCorrectionType = .temperature

    var originalValue: Observable<Double?> = Observable<Double?>()
    var updateAt: Observable<Date?> = Observable<Date?>()
    var offsetCorrectionValue: Observable<Double?> = Observable<Double?>()
    var offsetCorrectionDate: Observable<Date?> = Observable<Date?>()
    var correctedValue: Observable<Double?> = Observable<Double?>()

    let temperatureUnit: Observable<TemperatureUnit?> = Observable<TemperatureUnit?>()
    let humidityUnit: Observable<HumidityUnit?> = Observable<HumidityUnit?>()
    let pressureUnit: Observable<UnitPressure?> = Observable<UnitPressure?>()

    var title: String {
        switch type {
        case .humidity:
            return "OffsetCorrection.Humidity.Title".localized()
        case .pressure:
            return "OffsetCorrection.Pressure.Title".localized()
        default:
            return "OffsetCorrection.Temperature.Title".localized()
        }
    }

    var hasOffsetValue: Observable<Bool?> = Observable<Bool?>(false)

    init() {
        type = .pressure
        hasOffsetValue.value = false
    }

    convenience init(type: OffsetCorrectionType,
                     sensorSettings: SensorSettings) {
        self.init()
        self.type = type
        self.update(sensorSettings: sensorSettings)
    }

    func update(ruuviTag: RuuviTag) {
        switch type {
        case .humidity:
            if let value = ruuviTag.humidity?.value {
                self.originalValue.value = value - ruuviTag.humidityOffset
                self.correctedValue.value = value
            }
        case .pressure:
            if let value = ruuviTag.pressure?.value {
                self.originalValue.value = value - ruuviTag.pressureOffset
                self.correctedValue.value = value
            }
        default:
            if let value = ruuviTag.temperature?.value {
                self.originalValue.value = value - ruuviTag.temperatureOffset
                self.correctedValue.value = value
            }
        }
        self.updateAt.value = Date()
    }

    func update(ruuviTagRecord: RuuviTagSensorRecord) {
        switch type {
        case .humidity:
            if let value = ruuviTagRecord.humidity?.value {
                self.originalValue.value = value - ruuviTagRecord.humidityOffset
                self.correctedValue.value = value
            }
        case .pressure:
            if let value = ruuviTagRecord.pressure?.value {
                self.originalValue.value = value - ruuviTagRecord.pressureOffset
                self.correctedValue.value = value
            }
        default:
            if let value = ruuviTagRecord.temperature?.value {
                self.originalValue.value = value - ruuviTagRecord.temperatureOffset
                self.correctedValue.value = value
            }
        }
        self.updateAt.value = Date()
    }

    func update(sensorSettings: SensorSettings) {
        switch type {
        case .humidity:
            self.offsetCorrectionValue.value = sensorSettings.humidityOffset
            self.offsetCorrectionDate.value = sensorSettings.humidityOffsetDate
        case .pressure:
            self.offsetCorrectionValue.value = sensorSettings.pressureOffset
            self.offsetCorrectionDate.value = sensorSettings.pressureOffsetDate
        default:
            self.offsetCorrectionValue.value = sensorSettings.temperatureOffset
            self.offsetCorrectionDate.value = sensorSettings.temperatureOffsetDate
        }

        if let value = self.offsetCorrectionValue.value, value != 0 {
            self.hasOffsetValue.value = true
        } else {
            self.hasOffsetValue.value = false
        }
    }
}
