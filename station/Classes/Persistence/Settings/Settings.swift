import Foundation

extension Notification.Name {
    static let TemperatureUnitDidChange = Notification.Name("Settings.TemperatureUnitDidChange")
    static let HumidityUnitDidChange = Notification.Name("Settings.HumidityUnitDidChange")
}

protocol Settings {
    var temperatureUnit: TemperatureUnit { get set }
    var humidityUnit: HumidityUnit { get set }
    var welcomeShown: Bool { get set }
    var experimentalUX: Bool { get set }
}
