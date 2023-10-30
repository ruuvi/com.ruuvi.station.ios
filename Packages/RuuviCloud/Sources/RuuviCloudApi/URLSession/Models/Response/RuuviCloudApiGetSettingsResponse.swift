import Foundation
import RuuviOntology
import Humidity

public struct RuuviCloudApiGetSettingsResponse: Decodable {
    public let settings: RuuviCloudApiSettings?
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
    public var chartShowMinMaxAvg: Bool? {
        return chartShowMinMaxAverageString?.ruuviCloudApiSettingBoolean
    }
    public var cloudModeEnabled: Bool? {
        return cloudModeEnabledString?.ruuviCloudApiSettingBoolean
    }
    public var dashboardEnabled: Bool? {
        return dashboardEnabledString?.ruuviCloudApiSettingBoolean
    }
    public var dashboardType: DashboardType? {
        return dashboardTypeString?.ruuviCloudApiSettingsDashboardType
    }
    public var dashboardTapActionType: DashboardTapActionType? {
        return dashboardTapActionTypeString?.ruuviCloudApiSettingsDashboardTapActionType
    }
    public var pushAlertEnabled: Bool? {
        return pushAlertEnabledString?.ruuviCloudApiSettingBoolean
    }
    public var emailAlertEnabled: Bool? {
        return emailAlertEnabledString?.ruuviCloudApiSettingBoolean
    }
    public var profileLanguageCode: String? {
        return profileLanguageCodeString
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
    var chartShowMinMaxAverageString: String?
    var cloudModeEnabledString: String?
    var dashboardEnabledString: String?
    var dashboardTypeString: String?
    var dashboardTapActionTypeString: String?
    var pushAlertEnabledString: String?
    var emailAlertEnabledString: String?
    var profileLanguageCodeString: String?

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
        case chartShowMinMaxAverageString = "CHART_SHOW_MIN_MAX_AVG"
        case cloudModeEnabledString = "CLOUD_MODE_ENABLED"
        case dashboardEnabledString = "DASHBOARD_ENABLED"
        case dashboardTypeString = "DASHBOARD_TYPE"
        case dashboardTapActionTypeString = "DASHBOARD_TAP_ACTION"
        case pushAlertEnabledString = "ALERT_PUSH_ENABLED"
        case emailAlertEnabledString = "ALERT_EMAIL_ENABLED"
        case profileLanguageCodeString = "PROFILE_LANGUAGE_CODE"
    }
}
