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

public extension WidgetSensorEnum {
    static let ruuviTag: [WidgetSensorEnum] = [
        .temperature, .humidity, .pressure, .movement_counter,
        .battery_voltage, .acceleration_x, .acceleration_y, .acceleration_z,
    ]

    static let ruuviAir: [WidgetSensorEnum] = [
        .temperature, .humidity, .pressure, .air_quality,
        .co2, .nox, .voc, .pm25, .pm100, .luminance,
    ]
}

public extension WidgetSensorEnum {

    // swiftlint:disable:next cyclomatic_complexity
    func displayName() -> String {
        switch self {
        case .temperature:
            RuuviLocalization.temperature
        case .humidity:
            RuuviLocalization.relHumidity
        case .pressure:
            RuuviLocalization.pressure
        case .movement_counter:
            RuuviLocalization.movements
        case .battery_voltage:
            RuuviLocalization.batteryVoltage
        case .acceleration_x:
            RuuviLocalization.accX
        case .acceleration_y:
            RuuviLocalization.accY
        case .acceleration_z:
            RuuviLocalization.accZ
        case .air_quality:
            RuuviLocalization.airQuality
        case .co2:
            RuuviLocalization.co2
        case .nox:
            RuuviLocalization.nox
        case .voc:
            RuuviLocalization.voc
        case .pm10:
            RuuviLocalization.pm10
        case .pm25:
            RuuviLocalization.pm25
        case .pm40:
            RuuviLocalization.pm40
        case .pm100:
            RuuviLocalization.pm100
        case .luminance:
            RuuviLocalization.light
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
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
