import Foundation
import Humidity
import RuuviOntology

public struct RuuviCloudApiGetSettingsResponse: Decodable {
    public let settings: RuuviCloudApiSettings?
}

public struct RuuviCloudApiSettings: Decodable, RuuviCloudSettings {
    public var unitTemperature: TemperatureUnit? {
        unitTemperatureString?.ruuviCloudApiSettingUnitTemperature
    }

    public var unitTemperatureLastUpdated: Date? {
        lastUpdatedDate(unitTemperatureLastUpdatedUnix)
    }

    public var accuracyTemperature: MeasurementAccuracyType? {
        accuracyTemperatureString?.ruuviCloudApiSettingsMeasurementAccuracyUnit
    }

    public var accuracyTemperatureLastUpdated: Date? {
        lastUpdatedDate(accuracyTemperatureLastUpdatedUnix)
    }

    public var unitHumidity: HumidityUnit? {
        unitHumidityString?.ruuviCloudApiSettingUnitHumidity
    }

    public var unitHumidityLastUpdated: Date? {
        lastUpdatedDate(unitHumidityLastUpdatedUnix)
    }

    public var accuracyHumidity: MeasurementAccuracyType? {
        accuracyHumidityString?.ruuviCloudApiSettingsMeasurementAccuracyUnit
    }

    public var accuracyHumidityLastUpdated: Date? {
        lastUpdatedDate(accuracyHumidityLastUpdatedUnix)
    }

    public var unitPressure: UnitPressure? {
        unitPressureString?.ruuviCloudApiSettingUnitPressure
    }

    public var unitPressureLastUpdated: Date? {
        lastUpdatedDate(unitPressureLastUpdatedUnix)
    }

    public var accuracyPressure: MeasurementAccuracyType? {
        accuracyPressureString?.ruuviCloudApiSettingsMeasurementAccuracyUnit
    }

    public var accuracyPressureLastUpdated: Date? {
        lastUpdatedDate(accuracyPressureLastUpdatedUnix)
    }

    public var chartShowAllPoints: Bool? {
        chartShowAllPointsString?.ruuviCloudApiSettingBoolean
    }

    public var chartShowAllPointsLastUpdated: Date? {
        lastUpdatedDate(chartShowAllPointsLastUpdatedUnix)
    }

    public var chartDrawDots: Bool? {
        chartDrawDotsString?.ruuviCloudApiSettingBoolean
    }

    public var chartDrawDotsLastUpdated: Date? {
        lastUpdatedDate(chartDrawDotsLastUpdatedUnix)
    }

    public var chartViewPeriod: Int? {
        chartViewPeriodString?.ruuviCloudApiSettingChartViewPeriod
    }

    public var chartViewPeriodLastUpdated: Date? {
        lastUpdatedDate(chartViewPeriodLastUpdatedUnix)
    }

    public var chartShowMinMaxAvg: Bool? {
        chartShowMinMaxAverageString?.ruuviCloudApiSettingBoolean
    }

    public var chartShowMinMaxAvgLastUpdated: Date? {
        lastUpdatedDate(chartShowMinMaxAverageLastUpdatedUnix)
    }

    public var cloudModeEnabled: Bool? {
        cloudModeEnabledString?.ruuviCloudApiSettingBoolean
    }

    public var cloudModeEnabledLastUpdated: Date? {
        lastUpdatedDate(cloudModeEnabledLastUpdatedUnix)
    }

    public var dashboardEnabled: Bool? {
        dashboardEnabledString?.ruuviCloudApiSettingBoolean
    }

    public var dashboardEnabledLastUpdated: Date? {
        lastUpdatedDate(dashboardEnabledLastUpdatedUnix)
    }

    public var dashboardType: DashboardType? {
        dashboardTypeString?.ruuviCloudApiSettingsDashboardType
    }

    public var dashboardTypeLastUpdated: Date? {
        lastUpdatedDate(dashboardTypeLastUpdatedUnix)
    }

    public var dashboardTapActionType: DashboardTapActionType? {
        dashboardTapActionTypeString?.ruuviCloudApiSettingsDashboardTapActionType
    }

    public var dashboardTapActionTypeLastUpdated: Date? {
        lastUpdatedDate(dashboardTapActionTypeLastUpdatedUnix)
    }

    public var pushAlertDisabled: Bool? {
        pushAlertDisabledString?.ruuviCloudApiSettingBoolean
    }

    public var pushAlertDisabledLastUpdated: Date? {
        lastUpdatedDate(pushAlertDisabledLastUpdatedUnix)
    }

    public var emailAlertDisabled: Bool? {
        emailAlertDisabledString?.ruuviCloudApiSettingBoolean
    }

    public var emailAlertDisabledLastUpdated: Date? {
        lastUpdatedDate(emailAlertDisabledLastUpdatedUnix)
    }

    public var marketingPreference: Bool? {
        marketingPreferenceString?.ruuviCloudApiSettingBoolean
    }

    public var marketingPreferenceLastUpdated: Date? {
        lastUpdatedDate(marketingPreferenceLastUpdatedUnix)
    }

    public var profileLanguageCode: String? {
        profileLanguageCodeString
    }

    public var profileLanguageCodeLastUpdated: Date? {
        lastUpdatedDate(profileLanguageCodeLastUpdatedUnix)
    }

    public var dashboardSensorOrder: String? {
        dashboardSensorOrderString
    }

    public var dashboardSensorOrderLastUpdated: Date? {
        lastUpdatedDate(dashboardSensorOrderLastUpdatedUnix)
    }

    var unitTemperatureString: String?
    var unitTemperatureLastUpdatedUnix: Int?
    var accuracyTemperatureString: String?
    var accuracyTemperatureLastUpdatedUnix: Int?
    var unitHumidityString: String?
    var unitHumidityLastUpdatedUnix: Int?
    var accuracyHumidityString: String?
    var accuracyHumidityLastUpdatedUnix: Int?
    var unitPressureString: String?
    var unitPressureLastUpdatedUnix: Int?
    var accuracyPressureString: String?
    var accuracyPressureLastUpdatedUnix: Int?
    var chartShowAllPointsString: String?
    var chartShowAllPointsLastUpdatedUnix: Int?
    var chartDrawDotsString: String?
    var chartDrawDotsLastUpdatedUnix: Int?
    var chartViewPeriodString: String?
    var chartViewPeriodLastUpdatedUnix: Int?
    var chartShowMinMaxAverageString: String?
    var chartShowMinMaxAverageLastUpdatedUnix: Int?
    var cloudModeEnabledString: String?
    var cloudModeEnabledLastUpdatedUnix: Int?
    var dashboardEnabledString: String?
    var dashboardEnabledLastUpdatedUnix: Int?
    var dashboardTypeString: String?
    var dashboardTypeLastUpdatedUnix: Int?
    var dashboardTapActionTypeString: String?
    var dashboardTapActionTypeLastUpdatedUnix: Int?
    var emailAlertDisabledString: String?
    var emailAlertDisabledLastUpdatedUnix: Int?
    var pushAlertDisabledString: String?
    var pushAlertDisabledLastUpdatedUnix: Int?
    var marketingPreferenceString: String?
    var marketingPreferenceLastUpdatedUnix: Int?
    var profileLanguageCodeString: String?
    var profileLanguageCodeLastUpdatedUnix: Int?
    var dashboardSensorOrderString: String?
    var dashboardSensorOrderLastUpdatedUnix: Int?

    enum CodingKeys: String, CodingKey {
        case unitTemperatureString = "UNIT_TEMPERATURE"
        case unitTemperatureLastUpdatedUnix = "UNIT_TEMPERATURE_lastUpdated"
        case accuracyTemperatureString = "ACCURACY_TEMPERATURE"
        case accuracyTemperatureLastUpdatedUnix = "ACCURACY_TEMPERATURE_lastUpdated"
        case unitHumidityString = "UNIT_HUMIDITY"
        case unitHumidityLastUpdatedUnix = "UNIT_HUMIDITY_lastUpdated"
        case accuracyHumidityString = "ACCURACY_HUMIDITY"
        case accuracyHumidityLastUpdatedUnix = "ACCURACY_HUMIDITY_lastUpdated"
        case unitPressureString = "UNIT_PRESSURE"
        case unitPressureLastUpdatedUnix = "UNIT_PRESSURE_lastUpdated"
        case accuracyPressureString = "ACCURACY_PRESSURE"
        case accuracyPressureLastUpdatedUnix = "ACCURACY_PRESSURE_lastUpdated"
        case chartShowAllPointsString = "CHART_SHOW_ALL_POINTS"
        case chartShowAllPointsLastUpdatedUnix = "CHART_SHOW_ALL_POINTS_lastUpdated"
        case chartDrawDotsString = "CHART_DRAW_DOTS"
        case chartDrawDotsLastUpdatedUnix = "CHART_DRAW_DOTS_lastUpdated"
        case chartViewPeriodString = "CHART_VIEW_PERIOD"
        case chartViewPeriodLastUpdatedUnix = "CHART_VIEW_PERIOD_lastUpdated"
        case chartShowMinMaxAverageString = "CHART_SHOW_MIN_MAX_AVG"
        case chartShowMinMaxAverageLastUpdatedUnix = "CHART_SHOW_MIN_MAX_AVG_lastUpdated"
        case cloudModeEnabledString = "CLOUD_MODE_ENABLED"
        case cloudModeEnabledLastUpdatedUnix = "CLOUD_MODE_ENABLED_lastUpdated"
        case dashboardEnabledString = "DASHBOARD_ENABLED"
        case dashboardEnabledLastUpdatedUnix = "DASHBOARD_ENABLED_lastUpdated"
        case dashboardTypeString = "DASHBOARD_TYPE"
        case dashboardTypeLastUpdatedUnix = "DASHBOARD_TYPE_lastUpdated"
        case dashboardTapActionTypeString = "DASHBOARD_TAP_ACTION"
        case dashboardTapActionTypeLastUpdatedUnix = "DASHBOARD_TAP_ACTION_lastUpdated"
        case emailAlertDisabledString = "DISABLE_EMAIL_NOTIFICATIONS"
        case emailAlertDisabledLastUpdatedUnix = "DISABLE_EMAIL_NOTIFICATIONS_lastUpdated"
        case pushAlertDisabledString = "DISABLE_PUSH_NOTIFICATIONS"
        case pushAlertDisabledLastUpdatedUnix = "DISABLE_PUSH_NOTIFICATIONS_lastUpdated"
        case marketingPreferenceString = "MARKETING_PREFERENCE"
        case marketingPreferenceLastUpdatedUnix = "MARKETING_PREFERENCE_lastUpdated"
        case profileLanguageCodeString = "PROFILE_LANGUAGE_CODE"
        case profileLanguageCodeLastUpdatedUnix = "PROFILE_LANGUAGE_CODE_lastUpdated"
        case dashboardSensorOrderString = "SENSOR_ORDER"
        case dashboardSensorOrderLastUpdatedUnix = "SENSOR_ORDER_lastUpdated"
    }

    private func lastUpdatedDate(_ timestamp: Int?) -> Date? {
        guard let timestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}
