import Foundation

extension Notification.Name {
    static let TemperatureUnitDidChange = Notification.Name("Settings.TemperatureUnitDidChange")
    static let HumidityUnitDidChange = Notification.Name("Settings.HumidityUnitDidChange")
    static let PressureUnitDidChange = Notification.Name("Settings.PressureUnitDidChange")
    static let LanguageDidChange = Notification.Name("LanguageDidChange")
    static let isAdvertisementDaemonOnDidChange = Notification.Name("isAdvertisementDaemonOnDidChange")
    static let isWebTagDaemonOnDidChange = Notification.Name("isWebTagDaemonOnDidChange")
    static let WebTagDaemonIntervalDidChange = Notification.Name("WebTagDaemonIntervalDidChange")
    static let ReadRSSIDidChange = Notification.Name("ReadRSSIDidChange")
    static let ReadRSSIIntervalDidChange = Notification.Name("ReadRSSIIntervalDidChange")
    static let DownsampleOnDidChange = Notification.Name("DownsampleOnDidChange")
    static let ChartIntervalDidChange = Notification.Name("ChartIntervalDidChange")
}

protocol Settings {
    var temperatureUnit: TemperatureUnit { get set }
    var humidityUnit: HumidityUnit { get set }
    var pressureUnit: UnitPressure { get set }
    var welcomeShown: Bool { get set }
    var tagChartsLandscapeSwipeInstructionWasShown: Bool { get set }
    var language: Language { get set }
    var isAdvertisementDaemonOn: Bool { get set }
    var advertisementDaemonIntervalMinutes: Int { get set }
    var isWebTagDaemonOn: Bool { get set }
    var webTagDaemonIntervalMinutes: Int { get set }
    var connectionTimeout: TimeInterval { get set }
    var serviceTimeout: TimeInterval { get set }
    var cardsSwipeHintWasShown: Bool { get set }
    var alertsRepeatingIntervalMinutes: Int { get set }
    var saveHeartbeats: Bool { get set }
    var saveHeartbeatsIntervalMinutes: Int { get set }
    var readRSSI: Bool { get set }
    var readRSSIIntervalSeconds: Int { get set }
    var webPullIntervalMinutes: Int { get set }
    var dataPruningOffsetHours: Int { get set }
    var chartIntervalSeconds: Int { get set }
    var chartDurationHours: Int { get set }
    var chartDownsamplingOn: Bool { get set }
    var tagsSorting: [String] { get set }

    func keepConnectionDialogWasShown(for luid: LocalIdentifier) -> Bool
    func setKeepConnectionDialogWasShown(for luid: LocalIdentifier)
}
