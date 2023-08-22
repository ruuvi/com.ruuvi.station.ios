import Foundation
import RuuviOntology
import RuuviLocal

// swiftlint:disable type_body_length file_length
final class RuuviLocalSettingsUserDefaults: RuuviLocalSettings {

    @UserDefault("SettingsUserDefaults.isSyncing", defaultValue: false)
    var isSyncing: Bool

    private let keepConnectionDialogWasShownUDPrefix = "SettingsUserDegaults.keepConnectionDialogWasShownUDPrefix."

    func keepConnectionDialogWasShown(for luid: LocalIdentifier) -> Bool {
        return UserDefaults.standard.bool(forKey: keepConnectionDialogWasShownUDPrefix + luid.value)
    }

    func setKeepConnectionDialogWasShown(for luid: LocalIdentifier) {
        UserDefaults.standard.set(true, forKey: keepConnectionDialogWasShownUDPrefix + luid.value)
    }

    private let firmwareUpdateDialogWasShownUDPrefix = "SettingsUserDegaults.firmwareUpdateDialogWasShownUDPrefix."

    func firmwareUpdateDialogWasShown(for luid: LocalIdentifier) -> Bool {
        return UserDefaults.standard.bool(forKey: firmwareUpdateDialogWasShownUDPrefix + luid.value)
    }

    func setFirmwareUpdateDialogWasShown(for luid: LocalIdentifier) {
        UserDefaults.standard.set(true, forKey: firmwareUpdateDialogWasShownUDPrefix + luid.value)
    }

    // TODO: - Deprecate this after version v1.3.2
    private let firmwareVersionPrefix = "SettingsUserDegaults.firmwareVersionPrefix"
    func firmwareVersion(for luid: LocalIdentifier) -> String? {
        return UserDefaults.standard.value(forKey: firmwareVersionPrefix + luid.value) as? String
    }

    func setFirmwareVersion(for luid: LocalIdentifier, value: String?) {
        UserDefaults.standard.set(value, forKey: firmwareVersionPrefix + luid.value)
    }

    private let notificationServiceAppGroup = UserDefaults(suiteName: "group.com.ruuvi.station.pnservice")
    var language: Language {
        get {
            if let savedCode = UserDefaults.standard.string(forKey: languageUDKey) {
                return Language(rawValue: savedCode) ?? .english
            } else if let regionCode = Locale.current.languageCode {
                return Language(rawValue: regionCode) ?? .english
            } else {
                return .english
            }
        }
        set {
            notificationServiceAppGroup?.set(newValue.rawValue, forKey: languageUDKey)
            notificationServiceAppGroup?.synchronize()
            UserDefaults.standard.set(newValue.rawValue, forKey: languageUDKey)
            NotificationCenter
                .default
                .post(name: .LanguageDidChange,
                      object: self,
                      userInfo: nil)
        }
    }
    private let languageUDKey = "SettingsUserDegaults.languageUDKey"

    var humidityUnit: HumidityUnit {
        get {
            switch humidityUnitInt {
            case 1:
                return .gm3
            case 2:
                return .dew
            default:
                return .percent
            }
        }
        set {
            switch newValue {
            case .percent:
                humidityUnitInt = 0
            case .gm3:
                humidityUnitInt = 1
            case .dew:
                humidityUnitInt = 2
            }
            NotificationCenter
                .default
                .post(name: .HumidityUnitDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDefaults.humidityAccuracyInt", defaultValue: MeasurementAccuracyType.two.value)
    private var humidityAccuracyInt: Int

    var humidityAccuracy: MeasurementAccuracyType {
        get {
            switch humidityAccuracyInt {
            case 0:
                return .zero
            case 1:
                return .one
            case 2:
                return .two
            default:
                return .two
            }
        }
        set {
            humidityAccuracyInt = newValue.value
            NotificationCenter
                .default
                .post(name: .HumidityAccuracyDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    var temperatureUnit: TemperatureUnit {
        get {
            switch temperatureUnitInt {
            case 0:
                return useFahrenheit ? .fahrenheit : .celsius
            case 1:
                return .kelvin
            case 2:
                return .celsius
            case 3:
                return .fahrenheit
            default:
                return .celsius
            }
        }
        set {
            useFahrenheit = newValue == .fahrenheit
            switch newValue {
            case .kelvin:
                temperatureUnitInt = 1
            case .celsius:
                temperatureUnitInt = 2
            case .fahrenheit:
                temperatureUnitInt = 3
            }
            NotificationCenter
                .default
                .post(name: .TemperatureUnitDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDefaults.temperatureAccuracyInt", defaultValue: MeasurementAccuracyType.two.value)
    private var temperatureAccuracyInt: Int

    var temperatureAccuracy: MeasurementAccuracyType {
        get {
            switch temperatureAccuracyInt {
            case 0:
                return .zero
            case 1:
                return .one
            case 2:
                return .two
            default:
                return .two
            }
        }
        set {
            temperatureAccuracyInt = newValue.value
            NotificationCenter
                .default
                .post(name: .TemperatureAccuracyDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    var pressureUnit: UnitPressure {
        get {
            switch pressureUnitInt {
            case UnitPressure.inchesOfMercury.hashValue:
                return .inchesOfMercury
            case UnitPressure.millimetersOfMercury.hashValue:
                return .millimetersOfMercury
            default:
                return .hectopascals
            }
        }
        set {
            pressureUnitInt = newValue.hashValue
            NotificationCenter
                .default
                .post(name: .PressureUnitDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDefaults.pressureAccuracyInt", defaultValue: MeasurementAccuracyType.two.value)
    private var pressureAccuracyInt: Int

    var pressureAccuracy: MeasurementAccuracyType {
        get {
            switch pressureAccuracyInt {
            case 0:
                return .zero
            case 1:
                return .one
            case 2:
                return .two
            default:
                return .two
            }
        }
        set {
            pressureAccuracyInt = newValue.value
            NotificationCenter
                .default
                .post(name: .PressureUnitAccuracyChange,
                      object: self,
                      userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDefaults.pressureUnitInt", defaultValue: UnitPressure.hectopascals.hashValue)
    private var pressureUnitInt: Int

    @UserDefault("SettingsUserDefaults.welcomeShown", defaultValue: false)
    var welcomeShown: Bool

    @UserDefault("SettingsUserDegaults.tagChartsLandscapeSwipeInstructionWasShown", defaultValue: false)
    var tagChartsLandscapeSwipeInstructionWasShown: Bool

    @UserDefault("DashboardScrollViewController.hasShownSwipeAlert", defaultValue: false)
     var cardsSwipeHintWasShown: Bool

    @UserDefault("SettingsUserDegaults.isAdvertisementDaemonOn", defaultValue: true)
    var isAdvertisementDaemonOn: Bool {
        didSet {
            NotificationCenter
            .default
            .post(name: .isAdvertisementDaemonOnDidChange,
                  object: self,
                  userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDegaults.isWebTagDaemonOn", defaultValue: true)
    var isWebTagDaemonOn: Bool {
        didSet {
            NotificationCenter
            .default
            .post(name: .isWebTagDaemonOnDidChange,
                  object: self,
                  userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDegaults.webTagDaemonIntervalMinutes", defaultValue: 60)
    var webTagDaemonIntervalMinutes: Int {

        didSet {
            NotificationCenter
            .default
            .post(name: .WebTagDaemonIntervalDidChange,
             object: self,
             userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDegaults.connectionTimeout", defaultValue: 30)
    var connectionTimeout: TimeInterval

    @UserDefault("SettingsUserDegaults.serviceTimeout", defaultValue: 300)
    var serviceTimeout: TimeInterval

    @UserDefault("SettingsUserDegaults.advertisementDaemonIntervalMinutes", defaultValue: 1)
    var advertisementDaemonIntervalMinutes: Int

    @UserDefault("SettingsUserDegaults.alertsMuteIntervalMinutes", defaultValue: 60)
    var alertsMuteIntervalMinutes: Int

    @UserDefault("SettingsUserDegaults.saveHeartbeats", defaultValue: true)
    var saveHeartbeats: Bool

    @UserDefault("SettingsUserDegaults.saveHeartbeatsIntervalMinutes", defaultValue: 5)
    var saveHeartbeatsIntervalMinutes: Int

    @UserDefault("SettingsUserDegaults.webPullIntervalMinutes", defaultValue: 15)
    var webPullIntervalMinutes: Int

    @UserDefault("SettingsUserDegaults.dataPruningOffsetHours", defaultValue: 240)
    var dataPruningOffsetHours: Int

    @UserDefault("SettingsUserDegaults.chartIntervalSeconds", defaultValue: 300)
    var chartIntervalSeconds: Int

    @UserDefault("SettingsUserDegaults.chartDurationHours", defaultValue: 240)
    var chartDurationHours: Int {
        didSet {
            NotificationCenter
                .default
                .post(name: .ChartDurationHourDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    // TODO: - Deprecate this once all users are migrated to hours.
    @UserDefault("SettingsUserDefaults.chartDurationHoursMigrated", defaultValue: false)
    var chartDurationHoursMigrated: Bool

    @UserDefault("SettingsUserDefaults.networkPullIntervalMinutes", defaultValue: 60)
    var networkPullIntervalSeconds: Int

    @UserDefault("SettingsUserDefaults.networkPruningIntervalHours", defaultValue: 240)
    var networkPruningIntervalHours: Int

    // MARK: - Private
    @UserDefault("SettingsUserDegaults.useFahrenheit", defaultValue: false)
    private var useFahrenheit: Bool

    private var temperatureUnitInt: Int {
        get {
            let int = UserDefaults.standard.integer(forKey: temperatureUnitIntUDKey)
            if int == 0 {
                if useFahrenheit {
                    temperatureUnit = .fahrenheit
                    return 3
                } else {
                    temperatureUnit = .celsius
                    return 2
                }
            } else {
                return int
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: temperatureUnitIntUDKey)
        }
    }
    private let temperatureUnitIntUDKey = "SettingsUserDegaults.temperatureUnitIntUDKey"

    private var humidityUnitInt: Int {
        get {
            return UserDefaults.standard.integer(forKey: humidityUnitIntUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: humidityUnitIntUDKey)
        }
    }
    private let humidityUnitIntUDKey = "SettingsUserDegaults.humidityUnitInt"

    @UserDefault("SettingsUserDefaults.chartDownsamplingOn", defaultValue: true)
    var chartDownsamplingOn: Bool {
        didSet {
            NotificationCenter
                .default
                .post(name: .DownsampleOnDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDefaults.chartDrawDotsOn", defaultValue: false)
    var chartDrawDotsOn: Bool {
        didSet {
            NotificationCenter
                .default
                .post(name: .ChartDrawDotsOnDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDefaults.chartStatsOn", defaultValue: true)
    var chartStatsOn: Bool {
        didSet {
            NotificationCenter
                .default
                .post(name: .ChartStatsOnDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDefaults.experimentalFeaturesEnabled", defaultValue: false)
    var experimentalFeaturesEnabled: Bool

    @UserDefault("SettingsUserDefaults.cloudModeEnabled", defaultValue: false)
    var cloudModeEnabled: Bool {
        didSet {
            NotificationCenter
                .default
                .post(name: .CloudModeDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDefaults.useSimpleWidget", defaultValue: true)
    var useSimpleWidget: Bool

    @UserDefault("SettingsUserDefaults.appIsOnForeground", defaultValue: false)
    var appIsOnForeground: Bool

    @UserDefault("SettingsUserDefaults.appOpenedCount", defaultValue: 0)
    var appOpenedCount: Int

    /// If app launch count is hit to this value for the first time, ask for review
    @UserDefault("SettingsUserDefaults.appOpenedInitialCountToAskReview", defaultValue: 50)
    var appOpenedInitialCountToAskReview: Int

    /// App launch count is divisible by this, ask for review
    @UserDefault("SettingsUserDefaults.appOpenedCountDivisibleToAskReview", defaultValue: 100)
    var appOpenedCountDivisibleToAskReview: Int

    private let cardToOpenFromWidgetKey = "SettingsUserDefaults.cardToOpenFromWidgetKey"
    func cardToOpenFromWidget() -> String? {
        UserDefaults.standard.value(forKey: cardToOpenFromWidgetKey) as? String
    }
    func setCardToOpenFromWidget(for macId: String?) {
        UserDefaults.standard.set(macId, forKey: cardToOpenFromWidgetKey)
    }

    private let lastOpenedChartKey = "SettingsUserDefaults.lastOpenedChart"
    func lastOpenedChart() -> String? {
        UserDefaults.standard.value(forKey: lastOpenedChartKey) as? String
    }

    func setLastOpenedChart(with id: String) {
        UserDefaults.standard.set(id, forKey: lastOpenedChartKey)
    }

    private let ownerCheckDateKey = "SettingsUserDefaults.ownerCheckDate"
    func setOwnerCheckDate(for macId: MACIdentifier?, value: Date?) {
        guard let macId = macId else { return }
        if let value = value {
            UserDefaults.standard.set(value, forKey: ownerCheckDateKey + macId.mac)
        } else {
            UserDefaults.standard.removeObject(forKey: ownerCheckDateKey + macId.mac)
        }
    }

    func ownerCheckDate(for macId: MACIdentifier?) -> Date? {
        guard let macId = macId else { return nil }
        return UserDefaults.standard.value(forKey: ownerCheckDateKey + macId.mac) as? Date
    }

    @UserDefault("SettingsUserDefaults.dashboardEnabled", defaultValue: true)
    var dashboardEnabled: Bool

    private let dashboardTypeIdKey = "SettingsUserDefaults.dashboardTypeIdKey"
    private var dashboardTypeId: Int {
        get {
            return UserDefaults.standard.integer(forKey: dashboardTypeIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dashboardTypeIdKey)
        }
    }

    var dashboardType: DashboardType {
        get {
            switch dashboardTypeId {
            case 0:
                return .image
            case 1:
                return .simple
            default:
                return .image
            }
        }
        set {
            switch newValue {
            case .image:
                dashboardTypeId = 0
            case .simple:
                dashboardTypeId = 1
            }
            NotificationCenter
                .default
                .post(name: .DashboardTypeDidChange,
                      object: self,
                      userInfo: [DashboardTypeKey.type: newValue])
        }
    }

    private let dashboardTapActionTypeIdKey =
        "SettingsUserDefaults.dashboardTapActionTypeIdKey"
    private var dashboardTapActionTypeId: Int {
        get {
            return UserDefaults.standard.integer(forKey: dashboardTapActionTypeIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dashboardTapActionTypeIdKey)
        }
    }

    // swiftlint:disable switch_case_alignment
    var dashboardTapActionType: DashboardTapActionType {
        get {
            switch dashboardTapActionTypeId {
                case 0:
                    return .card
                case 1:
                    return .chart
                default:
                    return .card
            }
        }
        set {
            switch newValue {
                case .card:
                    dashboardTapActionTypeId = 0
                case .chart:
                    dashboardTapActionTypeId = 1
            }
            NotificationCenter
                .default
                .post(name: .DashboardTapActionTypeDidChange,
                      object: self,
                      userInfo: [DashboardTapActionTypeKey.type: newValue])
        }
    }
    // swiftlint:enable switch_case_alignment

    private let ruuviThemeIdKey = "SettingsUserDefaults.ruuviThemeIdKey"
    private var ruuviThemeId: Int {
        get {
            return UserDefaults.standard.integer(forKey: ruuviThemeIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ruuviThemeIdKey)
        }
    }

    var theme: RuuviTheme {
        get {
            switch ruuviThemeId {
            case 0:
                return .system
            case 1:
                return .light
            case 2:
                return .dark
            default:
                return .system
            }
        }
        set {
            switch newValue {
            case .system:
                ruuviThemeId = 0
            case .light:
                ruuviThemeId = 1
            case .dark:
                ruuviThemeId = 2
            }
            NotificationCenter
                .default
                .post(name: .AppearanceSettingsDidChange,
                      object: self,
                      userInfo: [AppearanceTypeKey.style: newValue])
        }
    }

    private let syncDialogHiddenKey = "SettingsUserDefaults.syncDialogHiddenKey."
    func syncDialogHidden(for luid: LocalIdentifier) -> Bool {
        return UserDefaults.standard.bool(forKey: syncDialogHiddenKey + luid.value)
    }

    func setSyncDialogHidden(for luid: LocalIdentifier) {
        UserDefaults.standard.set(true, forKey: syncDialogHiddenKey + luid.value)
    }

    @UserDefault("SettingsUserDefaults.hideNFCForSensorContest", defaultValue: false)
    var hideNFCForSensorContest: Bool
    private let ruuviAlertSoundKey = "SettingsUserDefaults.ruuviAlertSoundKey"
    var alertSound: RuuviAlertSound {
        get {
            if let key = UserDefaults.standard.string(forKey: ruuviAlertSoundKey) {
                return RuuviAlertSound(rawValue: key) ?? .ruuviSpeak
            }
            return .ruuviSpeak
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: ruuviAlertSoundKey)
            NotificationCenter
                .default
                .post(name: .AlertSoundSettingsDidChange,
                      object: self,
                      userInfo: [AppearanceTypeKey.style: newValue])
        }
    }

    @UserDefault("SettingsUserDefaults.showEmailAlertSettings", defaultValue: false)
    var showEmailAlertSettings: Bool

    @UserDefault("SettingsUserDefaults.emailAlertEnabled", defaultValue: false)
    var emailAlertEnabled: Bool {
        didSet {
            DispatchQueue.global(qos: .userInitiated).async {
                NotificationCenter
                    .default
                    .post(name: .EmailAlertSettingsDidChange,
                          object: self,
                          userInfo: nil)
            }
        }
    }

    @UserDefault("SettingsUserDefaults.showPushAlertSettings", defaultValue: false)
    var showPushAlertSettings: Bool

    @UserDefault("SettingsUserDefaults.pushAlertEnabled", defaultValue: false)
    var pushAlertEnabled: Bool {
        didSet {
            DispatchQueue.global(qos: .userInitiated).async {
                NotificationCenter
                    .default
                    .post(name: .PushAlertSettingsDidChange,
                          object: self,
                          userInfo: nil)
            }
        }
    }

    @UserDefault("SettingsUserDefaults.limitAlertNotificationsEnabled", defaultValue: true)
    var limitAlertNotificationsEnabled: Bool {
        didSet {
            DispatchQueue.global(qos: .userInitiated).async {
                NotificationCenter
                    .default
                    .post(name: .LimitAlertNotificationsSettingsDidChange,
                          object: self,
                          userInfo: nil)
            }
        }
    }
}
// swiftlint:enable type_body_length file_length
