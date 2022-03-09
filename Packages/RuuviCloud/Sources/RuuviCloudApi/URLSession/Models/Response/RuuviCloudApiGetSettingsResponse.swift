import Foundation
import RuuviOntology
import Humidity

public struct RuuviCloudApiGetSettingsResponse: Decodable {
    public let settings: RuuviCloudApiSettings
}

public struct RuuviCloudApiSettings: Decodable, RuuviCloudSettings {
    public var unitTemperature: TemperatureUnit? {
        return unitTemperatureString?.ruuviCloudApiSettingUnitTemperature
    }
    public var unitHumidity: HumidityUnit? {
        return unitHumidityString?.ruuviCloudApiSettingUnitHumidity
    }
    public var unitPressure: UnitPressure? {
        return unitPressureString?.ruuviCloudApiSettingUnitPressure
    }
    public var chartShowAllPoints: Bool? {
        return chartShowAllPointsString?.ruuviCloudApiSettingBoolean
    }
    public var chartDrawDots: Bool? {
        return chartDrawDotsString?.ruuviCloudApiSettingBoolean
    }
    public var chartViewPeriod: Int? {
        return chartViewPeriodString?.ruuviCloudApiSettingChartViewPeriod
    }

    var unitTemperatureString: String?
    var unitHumidityString: String?
    var unitPressureString: String?
    var chartShowAllPointsString: String?
    var chartDrawDotsString: String?
    var chartViewPeriodString: String?

    enum CodingKeys: String, CodingKey {
        case unitTemperatureString = "UNIT_TEMPERATURE"
        case unitHumidityString = "UNIT_HUMIDITY"
        case unitPressureString = "UNIT_PRESSURE"
        case chartShowAllPointsString = "CHART_SHOW_ALL_POINTS"
        case chartDrawDotsString = "CHART_DRAW_DOTS"
        case chartViewPeriodString = "CHART_VIEW_PERIOD"
    }
}
