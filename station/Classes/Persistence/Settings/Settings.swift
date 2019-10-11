import Foundation

extension Notification.Name {
    static let TemperatureUnitDidChange = Notification.Name("Settings.TemperatureUnitDidChange")
    static let HumidityUnitDidChange = Notification.Name("Settings.HumidityUnitDidChange")
    static let LanguageDidChange = Notification.Name("LanguageDidChange")
}

protocol Settings {
    var temperatureUnit: TemperatureUnit { get set }
    var humidityUnit: HumidityUnit { get set }
    var welcomeShown: Bool { get set }
    var language: Language { get set }
    var isAdvertisementDaemonOn: Bool { get set }
    var isConnectionDaemonOn: Bool { get set }
}
