import Foundation

public protocol RuuviCloudSettings {
    var unitTemperature: TemperatureUnit? { get }
    var accuracyTemperature: MeasurementAccuracyType? { get }
    var unitHumidity: HumidityUnit? { get }
    var accuracyHumidity: MeasurementAccuracyType? { get }
    var unitPressure: UnitPressure? { get }
    var accuracyPressure: MeasurementAccuracyType? { get }
    var chartShowAllPoints: Bool? { get }
    var chartDrawDots: Bool? { get }
    var chartViewPeriod: Int? { get }
    var chartShowMinMaxAvg: Bool? { get }
    var cloudModeEnabled: Bool? { get }
    var dashboardEnabled: Bool? { get }
    var dashboardType: DashboardType? { get }
    var dashboardTapActionType: DashboardTapActionType? { get }
    var pushAlertEnabled: Bool? { get }
    var emailAlertEnabled: Bool? { get }
    var profileLanguageCode: String? { get }
    var dashboardSensorOrder: String? { get }
}
