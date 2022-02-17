import Foundation

public protocol RuuviCloudSettings {
    var unitTemperature: TemperatureUnit? { get }
    var unitHumidity: HumidityUnit? { get }
    var unitPressure: UnitPressure? { get }
    var chartShowAllPoints: Bool? { get }
    var chartDrawDots: Bool? { get }
    var chartViewPeriod: Int? { get }
}
