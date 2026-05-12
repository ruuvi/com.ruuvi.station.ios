import Foundation

public protocol RuuviCloudSettings {
    var unitTemperature: TemperatureUnit? { get }
    var unitTemperatureLastUpdated: Date? { get }
    var accuracyTemperature: MeasurementAccuracyType? { get }
    var accuracyTemperatureLastUpdated: Date? { get }
    var unitHumidity: HumidityUnit? { get }
    var unitHumidityLastUpdated: Date? { get }
    var accuracyHumidity: MeasurementAccuracyType? { get }
    var accuracyHumidityLastUpdated: Date? { get }
    var unitPressure: UnitPressure? { get }
    var unitPressureLastUpdated: Date? { get }
    var accuracyPressure: MeasurementAccuracyType? { get }
    var accuracyPressureLastUpdated: Date? { get }
    var chartShowAllPoints: Bool? { get }
    var chartShowAllPointsLastUpdated: Date? { get }
    var chartDrawDots: Bool? { get }
    var chartDrawDotsLastUpdated: Date? { get }
    var chartViewPeriod: Int? { get }
    var chartViewPeriodLastUpdated: Date? { get }
    var chartShowMinMaxAvg: Bool? { get }
    var chartShowMinMaxAvgLastUpdated: Date? { get }
    var cloudModeEnabled: Bool? { get }
    var cloudModeEnabledLastUpdated: Date? { get }
    var dashboardEnabled: Bool? { get }
    var dashboardEnabledLastUpdated: Date? { get }
    var dashboardType: DashboardType? { get }
    var dashboardTypeLastUpdated: Date? { get }
    var dashboardTapActionType: DashboardTapActionType? { get }
    var dashboardTapActionTypeLastUpdated: Date? { get }
    var pushAlertDisabled: Bool? { get }
    var pushAlertDisabledLastUpdated: Date? { get }
    var emailAlertDisabled: Bool? { get }
    var emailAlertDisabledLastUpdated: Date? { get }
    var marketingPreference: Bool? { get }
    var marketingPreferenceLastUpdated: Date? { get }
    var profileLanguageCode: String? { get }
    var profileLanguageCodeLastUpdated: Date? { get }
    var dashboardSensorOrder: String? { get }
    var dashboardSensorOrderLastUpdated: Date? { get }
}
