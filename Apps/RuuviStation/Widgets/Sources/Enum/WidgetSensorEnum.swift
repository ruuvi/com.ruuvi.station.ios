import Foundation
import RuuviLocalization

public enum WidgetSensorEnum: Int {
    case temperature = 1
    case humidity
    case pressure
    case movement_counter
    case battery_voltage
    case acceleration_x
    case acceleration_y
    case acceleration_z
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
        }
    }
}
