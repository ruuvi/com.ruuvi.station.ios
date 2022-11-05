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
    public var accuracyTemperature: MeasurementAccuracyType? {
        return accuracyTemperatureString?.ruuviCloudApiSettingsMeasurementAccuracyUnit
    }
    public var unitHumidity: HumidityUnit? {
        return unitHumidityString?.ruuviCloudApiSettingUnitHumidity
    }
    public var accuracyHumidity: MeasurementAccuracyType? {
        return accuracyHumidityString?.ruuviCloudApiSettingsMeasurementAccuracyUnit
    }
    public var unitPressure: UnitPressure? {
        return unitPressureString?.ruuviCloudApiSettingUnitPressure
    }
    public var accuracyPressure: MeasurementAccuracyType? {
        return accuracyPressureString?.ruuviCloudApiSettingsMeasurementAccuracyUnit
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
    public var cloudModeEnabled: Bool? {
        return cloudModeEnabledString?.ruuviCloudApiSettingBoolean
    }

    var unitTemperatureString: String?
    var accuracyTemperatureString: String?
    var unitHumidityString: String?
    var accuracyHumidityString: String?
    var unitPressureString: String?
    var accuracyPressureString: String?
    var chartShowAllPointsString: String?
    var chartDrawDotsString: String?
    var chartViewPeriodString: String?
    var cloudModeEnabledString: String?

    enum CodingKeys: String, CodingKey {
        case unitTemperatureString = "UNIT_TEMPERATURE"
        case accuracyTemperatureString = "ACCURACY_TEMPERATURE"
        case unitHumidityString = "UNIT_HUMIDITY"
        case accuracyHumidityString = "ACCURACY_HUMIDITY"
        case unitPressureString = "UNIT_PRESSURE"
        case accuracyPressureString = "ACCURACY_PRESSURE"
        case chartShowAllPointsString = "CHART_SHOW_ALL_POINTS"
        case chartDrawDotsString = "CHART_DRAW_DOTS"
        case chartViewPeriodString = "CHART_VIEW_PERIOD"
        case cloudModeEnabledString = "CLOUD_MODE_ENABLED"
    }
}
