import UIKit
import BTKit
import Humidity

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
        get {
            switch type {
            case .humidity:
                return "OffsetCorrection.Humidity.Title".localized()
            case .pressure:
                return "OffsetCorrection.Pressure.Title".localized()
            default:
                return "OffsetCorrection.Temperature.Title".localized()
            }
        }
    }

    var hasOffsetValue: Observable<Bool?> = Observable<Bool?>(false)

    init() {
        type = .pressure
        hasOffsetValue.value = false
    }

    convenience init(type: OffsetCorrectionType, sensorSettings: SensorSettings) {
        self.init()
        self.type = type
        self.update(sensorSettings: sensorSettings)
    }

    func update(ruuviTag: RuuviTag) {
        switch type {
        case .humidity:
            self.originalValue.value = ruuviTag.humidity?.value
        case .pressure:
            self.originalValue.value = ruuviTag.pressure?.converted(to: .hectopascals).value
        default:
            self.originalValue.value = ruuviTag.temperature?.converted(to: .celsius).value
        }
        self.correctedValue.value = (self.originalValue.value ?? 0) + (self.offsetCorrectionValue.value ?? 0)
        self.updateAt.value = Date()
    }

    func update(ruuviTagRecord: RuuviTagSensorRecord) {
        switch type {
        case .humidity:
            self.correctedValue.value = ruuviTagRecord.humidity?.value
        case .pressure:
            self.correctedValue.value
                = ruuviTagRecord.pressure?.converted(to: .hectopascals).value
        default:
            self.correctedValue.value
                = ruuviTagRecord.temperature?.converted(to: .celsius).value
        }
        self.originalValue.value = (self.correctedValue.value ?? 0) - (self.offsetCorrectionValue.value ?? 0)
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
        self.correctedValue.value = (self.originalValue.value ?? 0) + (self.offsetCorrectionValue.value ?? 0)
        self.hasOffsetValue.value = self.offsetCorrectionValue.value != nil
    }
}
