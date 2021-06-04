import Foundation

public protocol RuuviCloudSettings {
    var unitTemperature: TemperatureUnit? { get }
    var unitHumidity: HumidityUnit? { get }
    var unitPressure: UnitPressure? { get }
}
