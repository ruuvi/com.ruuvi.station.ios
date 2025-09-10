import Foundation
import RuuviLocalization
import RuuviOntology

public enum WidgetSensorEnum: Int {
    case temperature = 1
    case humidity
    case pressure
    case movement_counter
    case battery_voltage
    case acceleration_x
    case acceleration_y
    case acceleration_z
    case air_quality
    case co2
    case nox
    case voc
    case pm10
    case pm25
    case pm40
    case pm100
    case luminance
}

extension WidgetSensorEnum {
    func unit(from settings: MeasurementServiceSettings) -> String {
        switch self {
        case .temperature:
            settings.temperatureUnit.symbol
        case .humidity:
            settings.humidityUnit.symbol
        case .pressure:
            settings.pressureUnit.symbol
        case .movement_counter:
            RuuviLocalization.movements
        case .battery_voltage:
            "v"
        case .acceleration_x,
             .acceleration_y,
             .acceleration_z:
            "g"
        case .air_quality:
            ""
        case .co2:
            RuuviLocalization.unitCo2
        case .nox:
            RuuviLocalization.unitNox
        case .voc:
            RuuviLocalization.unitVoc
        case .pm10, .pm25, .pm40, .pm100:
            RuuviLocalization.unitPm10
        case .luminance:
            RuuviLocalization.unitLuminosity
        }
    }
}
