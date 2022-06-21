import Foundation

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
            return settings.temperatureUnit.symbol
        case .humidity:
            return settings.humidityUnit.symbol
        case .pressure:
            return settings.pressureUnit.symbol
        case .movement_counter:
            return "Cards.Movements.title".localized
        case .battery_voltage:
            return "v"
        case .acceleration_x,
                .acceleration_y,
                .acceleration_z:
            return "g"
        }
    }
}
