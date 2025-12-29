import Foundation
import RuuviOntology

// swiftlint:disable type_body_length file_length
final class RuuviLocalSettingsUserDefaults: RuuviLocalSettings {
    @UserDefault("SettingsUserDefaults.signedInAtleastOnce", defaultValue: false)
    var signedInAtleastOnce: Bool

    @UserDefault("SettingsUserDefaults.isSyncing", defaultValue: false)
    var isSyncing: Bool

    @UserDefault("SettingsUserDefaults.syncExtensiveChangesInProgress", defaultValue: false)
    var syncExtensiveChangesInProgress: Bool

    @UserDefault("SettingsUserDefaults.signalVisibilityMigrationInProgress", defaultValue: false)
    var signalVisibilityMigrationInProgress: Bool

    private let keepConnectionDialogWasShownUDPrefix = "SettingsUserDegaults.keepConnectionDialogWasShownUDPrefix."

    func keepConnectionDialogWasShown(for luid: LocalIdentifier) -> Bool {
        UserDefaults.standard.bool(forKey: keepConnectionDialogWasShownUDPrefix + luid.value)
    }

    func setKeepConnectionDialogWasShown(_ shown: Bool, for luid: LocalIdentifier) {
        UserDefaults.standard.set(shown, forKey: keepConnectionDialogWasShownUDPrefix + luid.value)
    }

    private let firmwareUpdateDialogWasShownUDPrefix = "SettingsUserDegaults.firmwareUpdateDialogWasShownUDPrefix."

    func firmwareUpdateDialogWasShown(for luid: LocalIdentifier) -> Bool {
        UserDefaults.standard.bool(forKey: firmwareUpdateDialogWasShownUDPrefix + luid.value)
    }

    func setFirmwareUpdateDialogWasShown(_ shown: Bool, for luid: LocalIdentifier) {
        UserDefaults.standard.set(shown, forKey: firmwareUpdateDialogWasShownUDPrefix + luid.value)
    }

    // TODO: - Deprecate this after version v1.3.2
    private let firmwareVersionPrefix = "SettingsUserDegaults.firmwareVersionPrefix"
    func firmwareVersion(for luid: LocalIdentifier) -> String? {
        UserDefaults.standard.value(forKey: firmwareVersionPrefix + luid.value) as? String
    }

    func setFirmwareVersion(for luid: LocalIdentifier, value: String?) {
        UserDefaults.standard.set(value, forKey: firmwareVersionPrefix + luid.value)
    }

    private let notificationServiceAppGroup = UserDefaults(suiteName: "group.com.ruuvi.station.pnservice")
    var language: Language {
        get {
            if let savedCode = notificationServiceAppGroup?.string(forKey: languageUDKey) {
                Language(rawValue: savedCode) ?? .english
            } else {
                .english
            }
        }
        set {
            notificationServiceAppGroup?.set(newValue.rawValue, forKey: languageUDKey)
            notificationServiceAppGroup?.synchronize()
            UserDefaults.standard.set(newValue.rawValue, forKey: languageUDKey)
            NotificationCenter
                .default
                .post(
                    name: .LanguageDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    private let languageUDKey = "SettingsUserDegaults.languageUDKey"

    @UserDefault("SettingsUserDefaults.cardToOpenFromWidgetKey", defaultValue: nil)
    var cloudProfileLanguageCode: String?

    var humidityUnit: HumidityUnit {
        get {
            switch humidityUnitInt {
            case 1:
                .gm3
            case 2:
                .dew
            default:
                .percent
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
                .post(
                    name: .HumidityUnitDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    @UserDefault("SettingsUserDefaults.humidityAccuracyInt", defaultValue: 2)
    private var humidityAccuracyInt: Int

    var humidityAccuracy: MeasurementAccuracyType {
        get {
            switch humidityAccuracyInt {
            case 0:
                .zero
            case 1:
                .one
            case 2:
                .two
            default:
                .two
            }
        }
        set {
            humidityAccuracyInt = newValue.value
            NotificationCenter
                .default
                .post(
                    name: .HumidityAccuracyDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    var temperatureUnit: TemperatureUnit {
        get {
            switch temperatureUnitInt {
            case 0:
                useFahrenheit ? .fahrenheit : .celsius
            case 1:
                .kelvin
            case 2:
                .celsius
            case 3:
                .fahrenheit
            default:
                .celsius
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
                .post(
                    name: .TemperatureUnitDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    @UserDefault("SettingsUserDefaults.temperatureAccuracyInt", defaultValue: 2)
    private var temperatureAccuracyInt: Int

    var temperatureAccuracy: MeasurementAccuracyType {
        get {
            switch temperatureAccuracyInt {
            case 0:
                .zero
            case 1:
                .one
            case 2:
                .two
            default:
                .two
            }
        }
        set {
            temperatureAccuracyInt = newValue.value
            NotificationCenter
                .default
                .post(
                    name: .TemperatureAccuracyDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    var pressureUnit: UnitPressure {
        get {
            switch pressureUnitInt {
            case UnitPressure.newtonsPerMetersSquared.hashValue:
                .newtonsPerMetersSquared
            case UnitPressure.inchesOfMercury.hashValue:
                .inchesOfMercury
            case UnitPressure.millimetersOfMercury.hashValue:
                .millimetersOfMercury
            default:
                .hectopascals
            }
        }
        set {
            pressureUnitInt = newValue.hashValue
            NotificationCenter
                .default
                .post(
                    name: .PressureUnitDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    @UserDefault("SettingsUserDefaults.pressureAccuracyInt", defaultValue: 2)
    private var pressureAccuracyInt: Int

    var pressureAccuracy: MeasurementAccuracyType {
        get {
            switch pressureAccuracyInt {
            case 0:
                .zero
            case 1:
                .one
            case 2:
                .two
            default:
                .two
            }
        }
        set {
            pressureAccuracyInt = newValue.value
            NotificationCenter
                .default
                .post(
                    name: .PressureUnitAccuracyChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    @UserDefault("SettingsUserDefaults.pressureUnitInt", defaultValue: UnitPressure.hectopascals.hashValue)
    private var pressureUnitInt: Int

    @UserDefault("SettingsUserDefaults.welcomeShown", defaultValue: false)
    var welcomeShown: Bool

    @UserDefault("SettingsUserDefaults.tosAccepted", defaultValue: false)
    var tosAccepted: Bool

    @UserDefault("SettingsUserDefaults.analyticsConsentGiven", defaultValue: false)
    var analyticsConsentGiven: Bool

    @UserDefault("SettingsUserDegaults.tagChartsLandscapeSwipeInstructionWasShown", defaultValue: false)
    var tagChartsLandscapeSwipeInstructionWasShown: Bool

    @UserDefault("DashboardScrollViewController.hasShownSwipeAlert", defaultValue: false)
    var cardsSwipeHintWasShown: Bool

    @UserDefault("SettingsUserDegaults.isAdvertisementDaemonOn", defaultValue: true)
    var isAdvertisementDaemonOn: Bool {
        didSet {
            NotificationCenter
                .default
                .post(
                    name: .isAdvertisementDaemonOnDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    @UserDefault("SettingsUserDegaults.connectionTimeout", defaultValue: 30)
    var connectionTimeout: TimeInterval

    @UserDefault("SettingsUserDegaults.serviceTimeout", defaultValue: 60)
    var serviceTimeout: TimeInterval

    @UserDefault("SettingsUserDegaults.advertisementDaemonIntervalMinutes", defaultValue: 1)
    var advertisementDaemonIntervalMinutes: Int

    @UserDefault("SettingsUserDegaults.alertsMuteIntervalMinutes", defaultValue: 60)
    var alertsMuteIntervalMinutes: Int

    @UserDefault("SettingsUserDefaults.movementAlertHysteresisMinutes", defaultValue: 5)
    var movementAlertHysteresisMinutes: Int
    private let movementAlertHysteresisLastEventsUDKey =
        "SettingsUserDefaults.movementAlertHysteresisLastEvents"

    func movementAlertHysteresisLastEvents() -> [String: Date] {
        let stored = UserDefaults.standard.dictionary(
            forKey: movementAlertHysteresisLastEventsUDKey
        ) ?? [:]
        var result = [String: Date]()
        result.reserveCapacity(stored.count)
        for (uuid, value) in stored {
            if let timeInterval = value as? TimeInterval {
                result[uuid] = Date(timeIntervalSince1970: timeInterval)
            } else if let number = value as? NSNumber {
                result[uuid] = Date(timeIntervalSince1970: number.doubleValue)
            }
        }
        return result
    }

    func setMovementAlertHysteresisLastEvents(_ values: [String: Date]) {
        let stored = values.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(
            stored,
            forKey: movementAlertHysteresisLastEventsUDKey
        )
    }

    @UserDefault("SettingsUserDegaults.saveHeartbeats", defaultValue: true)
    var saveHeartbeats: Bool

    @UserDefault("SettingsUserDegaults.saveHeartbeatsIntervalMinutes", defaultValue: 5)
    var saveHeartbeatsIntervalMinutes: Int

    @UserDefault("SettingsUserDefaults.saveHeartbeatsForegroundIntervalSeconds", defaultValue: 2)
    var saveHeartbeatsForegroundIntervalSeconds: Int

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
                .post(
                    name: .ChartDurationHourDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    @UserDefault("SettingsUserDefaults.networkPullIntervalMinutes", defaultValue: 60)
    var networkPullIntervalSeconds: Int

    @UserDefault("SettingsUserDefaults.widgetRefreshIntervalMinutes", defaultValue: 60)
    var widgetRefreshIntervalMinutes: Int {
        didSet {
            NotificationCenter
                .default
                .post(
                    name: .WidgetRefreshIntervalDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    @UserDefault("SettingsUserDefaults.forceRefreshWidget", defaultValue: false)
    var forceRefreshWidget: Bool

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
            UserDefaults.standard.integer(forKey: humidityUnitIntUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: humidityUnitIntUDKey)
        }
    }

    private let humidityUnitIntUDKey = "SettingsUserDegaults.humidityUnitInt"

    @UserDefault("SettingsUserDefaults.chartDownsamplingOn", defaultValue: false)
    var chartDownsamplingOn: Bool

    @UserDefault("SettingsUserDefaults.chartShowAllMeasurements", defaultValue: false)
    var chartShowAllMeasurements: Bool {
        didSet {
            NotificationCenter
                .default
                .post(
                    name: .DownsampleOnDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    @UserDefault("SettingsUserDefaults.chartDrawDotsOn", defaultValue: false)
    var chartDrawDotsOn: Bool {
        didSet {
            NotificationCenter
                .default
                .post(
                    name: .ChartDrawDotsOnDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    @UserDefault("SettingsUserDefaults.chartStatsOn", defaultValue: true)
    var chartStatsOn: Bool {
        didSet {
            NotificationCenter
                .default
                .post(
                    name: .ChartStatsOnDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    @UserDefault("SettingsUserDefaults.chartShowAll", defaultValue: true)
    var chartShowAll: Bool

    @UserDefault("SettingsUserDefaults.experimentalFeaturesEnabled", defaultValue: false)
    var experimentalFeaturesEnabled: Bool

    @UserDefault("SettingsUserDefaults.cloudModeEnabled", defaultValue: false)
    var cloudModeEnabled: Bool {
        didSet {
            NotificationCenter
                .default
                .post(
                    name: .CloudModeDidChange,
                    object: self,
                    userInfo: nil
                )
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

    func setLastOpenedChart(with id: String?) {
        UserDefaults.standard.set(id, forKey: lastOpenedChartKey)
    }

    private let ownerCheckDateKey = "SettingsUserDefaults.ownerCheckDate"
    func setOwnerCheckDate(for macId: MACIdentifier?, value: Date?) {
        guard let macId else { return }
        if let value {
            UserDefaults.standard.set(value, forKey: ownerCheckDateKey + macId.mac)
        } else {
            UserDefaults.standard.removeObject(forKey: ownerCheckDateKey + macId.mac)
        }
    }

    func ownerCheckDate(for macId: MACIdentifier?) -> Date? {
        guard let macId else { return nil }
        return UserDefaults.standard.value(forKey: ownerCheckDateKey + macId.mac) as? Date
    }

    @UserDefault("SettingsUserDefaults.dashboardEnabled", defaultValue: true)
    var dashboardEnabled: Bool

    private let dashboardTypeIdKey = "SettingsUserDefaults.dashboardTypeIdKey"
    private var dashboardTypeId: Int {
        get {
            UserDefaults.standard.integer(forKey: dashboardTypeIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dashboardTypeIdKey)
        }
    }

    var dashboardType: DashboardType {
        get {
            switch dashboardTypeId {
            case 0:
                .image
            case 1:
                .simple
            default:
                .image
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
                .post(
                    name: .DashboardTypeDidChange,
                    object: self,
                    userInfo: [DashboardTypeKey.type: newValue]
                )
        }
    }

    private let dashboardTapActionTypeIdKey =
        "SettingsUserDefaults.dashboardTapActionTypeIdKey"
    private var dashboardTapActionTypeId: Int {
        get {
            UserDefaults.standard.integer(forKey: dashboardTapActionTypeIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dashboardTapActionTypeIdKey)
        }
    }

    var dashboardTapActionType: DashboardTapActionType {
        get {
            switch dashboardTapActionTypeId {
            case 0:
                .card
            case 1:
                .chart
            default:
                .card
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
                .post(
                    name: .DashboardTapActionTypeDidChange,
                    object: self,
                    userInfo: [DashboardTapActionTypeKey.type: newValue]
                )
        }
    }

    @UserDefault("SettingsUserDefaults.showFullSensorCardOnDashboardTap", defaultValue: true)
    var showFullSensorCardOnDashboardTap: Bool

    private let dashboardSensorOrderIdKey =
        "SettingsUserDefaults.dashboardSortedSensors"
    var dashboardSensorOrder: [String] {
        get {
            UserDefaults.standard.value(
                forKey: dashboardSensorOrderIdKey
            ) as? [String] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dashboardSensorOrderIdKey)
            NotificationCenter
                .default
                .post(
                    name: .DashboardSensorOrderDidChange,
                    object: self,
                    userInfo: nil
                )
        }
    }

    private let ruuviThemeIdKey = "SettingsUserDefaults.ruuviThemeIdKey"
    private var ruuviThemeId: Int {
        get {
            UserDefaults.standard.integer(forKey: ruuviThemeIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ruuviThemeIdKey)
        }
    }

    var theme: RuuviTheme {
        get {
            switch ruuviThemeId {
            case 0:
                .system
            case 1:
                .light
            case 2:
                .dark
            default:
                .system
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
                .post(
                    name: .AppearanceSettingsDidChange,
                    object: self,
                    userInfo: [AppearanceTypeKey.style: newValue]
                )
        }
    }

    private let syncDialogHiddenKey = "SettingsUserDefaults.syncDialogHiddenKey."
    func syncDialogHidden(for luid: LocalIdentifier) -> Bool {
        UserDefaults.standard.bool(forKey: syncDialogHiddenKey + luid.value)
    }

    func setSyncDialogHidden(_ hidden: Bool, for luid: LocalIdentifier) {
        UserDefaults.standard.set(hidden, forKey: syncDialogHiddenKey + luid.value)
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
                .post(
                    name: .AlertSoundSettingsDidChange,
                    object: self,
                    userInfo: [AppearanceTypeKey.style: newValue]
                )
        }
    }

    @UserDefault("SettingsUserDefaults.emailAlertDisabled", defaultValue: false)
    var emailAlertDisabled: Bool {
        didSet {
            DispatchQueue.global(qos: .userInitiated).async {
                NotificationCenter
                    .default
                    .post(
                        name: .EmailAlertSettingsDidChange,
                        object: self,
                        userInfo: nil
                    )
            }
        }
    }

    @UserDefault("SettingsUserDefaults.pushAlertDisabled", defaultValue: false)
    var pushAlertDisabled: Bool {
        didSet {
            DispatchQueue.global(qos: .userInitiated).async {
                NotificationCenter
                    .default
                    .post(
                        name: .PushAlertSettingsDidChange,
                        object: self,
                        userInfo: nil
                    )
            }
        }
    }

    @UserDefault("SettingsUserDefaults.limitAlertNotificationsEnabled", defaultValue: true)
    var limitAlertNotificationsEnabled: Bool {
        didSet {
            DispatchQueue.global(qos: .userInitiated).async {
                NotificationCenter
                    .default
                    .post(
                        name: .LimitAlertNotificationsSettingsDidChange,
                        object: self,
                        userInfo: nil
                    )
            }
        }
    }

    @UserDefault("SettingsUserDefaults.showSwitchStatusLabel", defaultValue: true)
    var showSwitchStatusLabel: Bool

    private let notificationsBadgeCountUDKey = "SettingsUserDefaults.notificationsBadgeCount"
    func setNotificationsBadgeCount(value: Int) {
        notificationServiceAppGroup?
            .set(
                value,
                forKey: notificationsBadgeCountUDKey
            )
        notificationServiceAppGroup?.synchronize()
    }

    func notificationsBadgeCount() -> Int {
        return notificationServiceAppGroup?
            .integer(
                forKey: notificationsBadgeCountUDKey
            ) ?? 0
    }

    @UserDefault("SettingsUserDefaults.customTempAlertLowerBound", defaultValue: -55)
    var customTempAlertLowerBound: Double

    @UserDefault("SettingsUserDefaults.customTempAlertUpperBound", defaultValue: 150)
    var customTempAlertUpperBound: Double

    private let showCustomTempAlertBoundUDKey = "SettingsUserDefaults.showCustomTempAlertBoundUDKey"
    func showCustomTempAlertBound(for id: String) -> Bool {
        UserDefaults.standard.value(forKey: showCustomTempAlertBoundUDKey + id) as? Bool ?? false
    }

    func setShowCustomTempAlertBound(_ show: Bool, for id: String) {
        UserDefaults.standard.set(show, forKey: showCustomTempAlertBoundUDKey + id)
    }

    @UserDefault("SettingsUserDefaults.showAlertsRangeInGraph", defaultValue: true)
    var showAlertsRangeInGraph: Bool
    @UserDefault("SettingsUserDefaults.useNewGraphRendering", defaultValue: false)
    var useNewGraphRendering: Bool
    // On a scale of 10-100, 100 being best quality, and 10 being the worst.
    @UserDefault("SettingsUserDefaults.imageCompressionQuality", defaultValue: 40)
    var imageCompressionQuality: Int
    @UserDefault("SettingsUserDefaults.compactChatView", defaultValue: true)
    var compactChartView: Bool

    @UserDefault("SettingsUserDefaults.historySyncLegacy", defaultValue: false)
    var historySyncLegacy: Bool
    @UserDefault("SettingsUserDefaults.historySyncOnDashboard", defaultValue: false)
    var historySyncOnDashboard: Bool
    @UserDefault("SettingsUserDefaults.historySyncForEachSensor", defaultValue: true)
    var historySyncForEachSensor: Bool
    @UserDefault("SettingsUserDefaults.includeDataSourceInHistoryExport", defaultValue: false)
    var includeDataSourceInHistoryExport: Bool

    private let dashboardSignInBannerHiddenUDKey = "SettingsUserDefaults.dashboardSignInBannerHiddenUDKey"
    func dashboardSignInBannerHidden(for version: String) -> Bool {
        UserDefaults.standard.value(
            forKey: dashboardSignInBannerHiddenUDKey + version
        ) as? Bool ?? false
    }

    func setDashboardSignInBannerHidden(for version: String) {
        UserDefaults.standard.set(
            true,
            forKey: dashboardSignInBannerHiddenUDKey + version
        )
    }
}

// swiftlint:enable type_body_length file_length
