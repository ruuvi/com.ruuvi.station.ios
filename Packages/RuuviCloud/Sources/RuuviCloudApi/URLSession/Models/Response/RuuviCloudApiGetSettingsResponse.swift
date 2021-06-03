import Foundation
import RuuviOntology
import Humidity

struct RuuviCloudApiGetSettingsResponse: Decodable {
    let settings: RuuviCloudApiSettings
}

struct RuuviCloudApiSettings: Decodable, RuuviCloudSettings {
    var unitTemperature: TemperatureUnit? {
        if let unitTemperatureString = unitTemperatureString {
            switch unitTemperatureString {
            case "C":
                return .celsius
            case "F":
                return .fahrenheit
            case "K":
                return .kelvin
            default:
                return nil
            }
        } else {
            return nil
        }
    }
    var unitHumidity: HumidityUnit? {
        if let unitHumidityInt = unitHumidityInt {
            switch unitHumidityInt {
            case 0:
                return .percent
            case 1:
                return .gm3
            case 2:
                return .dew
            default:
                return nil
            }
        } else {
            return nil
        }
    }
    var unitPressure: UnitPressure? {
        if let unitPressureInt = unitPressureInt {
            switch unitPressureInt {
            case 0:
                return nil // TODO: @rinat support Pa
            case 1:
                return .hectopascals
            case 2:
                return .millimetersOfMercury
            case 3:
                return .inchesOfMercury
            default:
                return nil
            }
        } else {
            return nil
        }
    }

    var unitTemperatureString: String?
    var unitHumidityInt: Int?
    var unitPressureInt: Int?

    enum CodingKeys: String, CodingKey {
        case unitTemperatureString = "UNIT_TEMPERATURE"
        case unitHumidityInt = "UNIT_HUMIDITY"
        case unitPressureInt = "UNIT_PRESSURE"
    }
}
