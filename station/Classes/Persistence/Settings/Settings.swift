import Foundation

extension Notification.Name {
    static let TemperatureUnitDidChange = Notification.Name("Settings.TemperatureUnitDidChange")
}

protocol Settings {
    var temperatureUnit: TemperatureUnit { get set }
}
