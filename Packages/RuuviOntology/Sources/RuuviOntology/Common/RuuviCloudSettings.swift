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
    var cloudModeEnabled: Bool? { get }
}
