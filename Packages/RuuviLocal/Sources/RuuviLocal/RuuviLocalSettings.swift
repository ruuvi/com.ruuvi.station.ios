import Foundation
import RuuviOntology

public extension Notification.Name {
    static let TemperatureUnitDidChange = Notification.Name("Settings.TemperatureUnitDidChange")
    static let TemperatureAccuracyDidChange = Notification.Name("Settings.TemperatureAccuracyDidChange")
    static let HumidityUnitDidChange = Notification.Name("Settings.HumidityUnitDidChange")
    static let HumidityAccuracyDidChange = Notification.Name("Settings.HumidityAccuracyDidChange")
    static let PressureUnitDidChange = Notification.Name("Settings.PressureUnitDidChange")
    static let PressureUnitAccuracyChange = Notification.Name("Settings.PressureUnitAccuracyChange")
    static let LanguageDidChange = Notification.Name("LanguageDidChange")
    static let isAdvertisementDaemonOnDidChange = Notification.Name("isAdvertisementDaemonOnDidChange")
    static let DownsampleOnDidChange = Notification.Name("DownsampleOnDidChange")
    static let ChartDurationHourDidChange = Notification.Name("ChartDurationHourDidChange")
    static let ChartDrawDotsOnDidChange = Notification.Name("ChartDrawDotsOnDidChange")
    static let ChartStatsOnDidChange = Notification.Name("ChartStatsOnDidChange")
    static let CloudModeDidChange = Notification.Name("CloudModeDidChange")
    static let SensorCalibrationDidChange = Notification.Name("CalibrationDidChange")
    static let DashboardTypeDidChange = Notification.Name("DashboardTypeDidChange")
    static let DashboardTapActionTypeDidChange = Notification.Name("DashboardTapActionTypeDidChange")
    static let AppearanceSettingsDidChange = Notification.Name("AppearanceSettingsDidChange")
    static let AlertSoundSettingsDidChange = Notification.Name("AlertSoundSettingsDidChange")
    static let EmailAlertSettingsDidChange = Notification.Name("EmailAlertSettingsDidChange")
    static let PushAlertSettingsDidChange = Notification.Name("PushAlertSettingsDidChange")
    static let LimitAlertNotificationsSettingsDidChange =
        Notification.Name("LimitAlertNotificationsSettingsDidChange")
    static let DashboardSensorOrderDidChange = Notification.Name("DashboardSensorOrderDidChange")
}

public enum DashboardTypeKey: String {
    case type
}

public enum DashboardTapActionTypeKey: String {
    case type
}

public enum AppearanceTypeKey: String {
    case style
}

public protocol RuuviLocalSettings {
    var signedInAtleastOnce: Bool { get set }
    /// When syncing for the first time (after sign in) or extensive changes
    /// like cloud sync
    var isSyncing: Bool { get set }
    var temperatureUnit: TemperatureUnit { get set }
    var temperatureAccuracy: MeasurementAccuracyType { get set }
    var humidityUnit: HumidityUnit { get set }
    var humidityAccuracy: MeasurementAccuracyType { get set }
    var pressureUnit: UnitPressure { get set }
    var pressureAccuracy: MeasurementAccuracyType { get set }
    var welcomeShown: Bool { get set }
    var tagChartsLandscapeSwipeInstructionWasShown: Bool { get set }
    var language: Language { get set }
    var cloudProfileLanguageCode: String? { get set }
    var isAdvertisementDaemonOn: Bool { get set }
    var advertisementDaemonIntervalMinutes: Int { get set }
    var connectionTimeout: TimeInterval { get set }
    var serviceTimeout: TimeInterval { get set }
    var cardsSwipeHintWasShown: Bool { get set }
    var alertsMuteIntervalMinutes: Int { get set }
    var saveHeartbeats: Bool { get set }
    var saveHeartbeatsIntervalMinutes: Int { get set }
    var webPullIntervalMinutes: Int { get set }
    var dataPruningOffsetHours: Int { get set }
    var chartIntervalSeconds: Int { get set }
    var chartDurationHours: Int { get set }
    var chartDownsamplingOn: Bool { get set }
    var chartDrawDotsOn: Bool { get set }
    var chartStatsOn: Bool { get set }
    var chartShowAll: Bool { get set }
    var networkPullIntervalSeconds: Int { get set }
    var networkPruningIntervalHours: Int { get set }
    var experimentalFeaturesEnabled: Bool { get set }
    var cloudModeEnabled: Bool { get set }
    var useSimpleWidget: Bool { get set }
    var appIsOnForeground: Bool { get set }
    var appOpenedCount: Int { get set }
    var appOpenedInitialCountToAskReview: Int { get set }
    var appOpenedCountDivisibleToAskReview: Int { get set }
    var dashboardEnabled: Bool { get set }
    var dashboardType: DashboardType { get set }
    var dashboardTapActionType: DashboardTapActionType { get set }
    var dashboardSensorOrder: [String] { get set }
    var theme: RuuviTheme { get set }
    var hideNFCForSensorContest: Bool { get set }
    var alertSound: RuuviAlertSound { get set }
    var showEmailAlertSettings: Bool { get set }
    var emailAlertEnabled: Bool { get set }
    var showPushAlertSettings: Bool { get set }
    var pushAlertEnabled: Bool { get set }
    var limitAlertNotificationsEnabled: Bool { get set }

    func keepConnectionDialogWasShown(for luid: LocalIdentifier) -> Bool
    func setKeepConnectionDialogWasShown(for luid: LocalIdentifier)

    func firmwareUpdateDialogWasShown(for luid: LocalIdentifier) -> Bool
    func setFirmwareUpdateDialogWasShown(for luid: LocalIdentifier)

    func cardToOpenFromWidget() -> String?
    func setCardToOpenFromWidget(for macId: String?)

    func lastOpenedChart() -> String?
    func setLastOpenedChart(with id: String)

    func setOwnerCheckDate(for macId: MACIdentifier?, value: Date?)
    func ownerCheckDate(for macId: MACIdentifier?) -> Date?

    func syncDialogHidden(for luid: LocalIdentifier) -> Bool
    func setSyncDialogHidden(for luid: LocalIdentifier)

    func setNotificationsBadgeCount(value: Int)
    func notificationsBadgeCount() -> Int
}
