import Foundation
import RuuviOntology
import Humidity

struct RuuviCloudApiGetSettingsResponse: Decodable {
    let settings: RuuviCloudApiSettings
}

struct RuuviCloudApiSettings: Decodable, RuuviCloudSettings {
    var unitTemperature: TemperatureUnit? {
        return unitTemperatureString?.ruuviCloudApiSettingUnitTemperature
    }
    var unitHumidity: HumidityUnit? {
        return unitHumidityString?.ruuviCloudApiSettingUnitHumidity
    }
    var unitPressure: UnitPressure? {
        return unitPressureString?.ruuviCloudApiSettingUnitPressure
    }

    var unitTemperatureString: String?
    var unitHumidityString: String?
    var unitPressureString: String?

    enum CodingKeys: String, CodingKey {
        case unitTemperatureString = "UNIT_TEMPERATURE"
        case unitHumidityString = "UNIT_HUMIDITY"
        case unitPressureString = "UNIT_PRESSURE"
    }
}
