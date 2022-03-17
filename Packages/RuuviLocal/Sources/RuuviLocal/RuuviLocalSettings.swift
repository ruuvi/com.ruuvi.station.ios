import Foundation
import RuuviOntology

extension Notification.Name {
    public static let TemperatureUnitDidChange = Notification.Name("Settings.TemperatureUnitDidChange")
    public static let HumidityUnitDidChange = Notification.Name("Settings.HumidityUnitDidChange")
    public static let PressureUnitDidChange = Notification.Name("Settings.PressureUnitDidChange")
    public static let LanguageDidChange = Notification.Name("LanguageDidChange")
    public static let isAdvertisementDaemonOnDidChange = Notification.Name("isAdvertisementDaemonOnDidChange")
    public static let isWebTagDaemonOnDidChange = Notification.Name("isWebTagDaemonOnDidChange")
    public static let WebTagDaemonIntervalDidChange = Notification.Name("WebTagDaemonIntervalDidChange")
    public static let ReadRSSIDidChange = Notification.Name("ReadRSSIDidChange")
    public static let ReadRSSIIntervalDidChange = Notification.Name("ReadRSSIIntervalDidChange")
    public static let DownsampleOnDidChange = Notification.Name("DownsampleOnDidChange")
    public static let ChartIntervalDidChange = Notification.Name("ChartIntervalDidChange")
    public static let ChartDurationHourDidChange = Notification.Name("ChartDurationHourDidChange")
    public static let ChartDrawDotsOnDidChange = Notification.Name("ChartDrawDotsOnDidChange")
    public static let CloudModeDidChange = Notification.Name("CloudModeDidChange")
}

public protocol RuuviLocalSettings {
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
    var alertsMuteIntervalMinutes: Int { get set }
    var saveHeartbeats: Bool { get set }
    var saveHeartbeatsIntervalMinutes: Int { get set }
    var readRSSI: Bool { get set }
    var readRSSIIntervalSeconds: Int { get set }
    var webPullIntervalMinutes: Int { get set }
    var dataPruningOffsetHours: Int { get set }
    var chartIntervalSeconds: Int { get set }
    var chartDurationHours: Int { get set }
    var chartDownsamplingOn: Bool { get set }
    var chartDrawDotsOn: Bool { get set }
    var tagsSorting: [String] { get set }
    var networkPullIntervalSeconds: Int { get set }
    var networkPruningIntervalHours: Int { get set }
    var experimentalFeaturesEnabled: Bool { get set }
    var cloudModeEnabled: Bool { get set }

    func keepConnectionDialogWasShown(for luid: LocalIdentifier) -> Bool
    func setKeepConnectionDialogWasShown(for luid: LocalIdentifier)

    func firmwareUpdateDialogWasShown(for luid: LocalIdentifier) -> Bool
    func setFirmwareUpdateDialogWasShown(for luid: LocalIdentifier)

    func firmwareVersion(for luid: LocalIdentifier) -> String?
    func setFirmwareVersion(for luid: LocalIdentifier, value: String)
}
