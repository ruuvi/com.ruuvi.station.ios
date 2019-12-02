import Foundation

extension Notification.Name {
    static let TemperatureUnitDidChange = Notification.Name("Settings.TemperatureUnitDidChange")
    static let HumidityUnitDidChange = Notification.Name("Settings.HumidityUnitDidChange")
    static let LanguageDidChange = Notification.Name("LanguageDidChange")
    static let isAdvertisementDaemonOnDidChange = Notification.Name("isAdvertisementDaemonOnDidChange")
    static let isConnectionDaemonOnDidChange = Notification.Name("isConnectionDaemonOnDidChange")
    static let isWebTagDaemonOnDidChange = Notification.Name("isWebTagDaemonOnDidChange")
    static let WebTagDaemonIntervalDidChange = Notification.Name("WebTagDaemonIntervalDidChange")
}

protocol Settings {
    var temperatureUnit: TemperatureUnit { get set }
    var humidityUnit: HumidityUnit { get set }
    var welcomeShown: Bool { get set }
    var tagChartsLandscapeSwipeInstructionWasShown: Bool { get set }
    var language: Language { get set }
    var isAdvertisementDaemonOn: Bool { get set }
    var isConnectionDaemonOn: Bool { get set }
    var connectionDaemonIntervalMinutes: Int { get set }
    var advertisementDaemonIntervalMinutes: Int { get set }
    var isWebTagDaemonOn: Bool { get set }
    var webTagDaemonIntervalMinutes: Int { get set }
    var connectionTimeout: TimeInterval { get set }
    var serviceTimeout: TimeInterval { get set }
    var cardsSwipeHintWasShown: Bool { get set }
    var alertsRepeatingIntervalSeconds: Int { get set }

    func keepConnectionDialogWasShown(for uuid: String) -> Bool
    func setKeepConnectionDialogWasShown(for uuid: String)
}
