import Foundation
import RuuviLocal
import RuuviOntology

/// In-memory preferences keep app-hosted tests independent of the simulator account.
final class AppTestSettings: RuuviLocalSettings {
    var signedInAtleastOnce: Bool = false
    var isSyncing: Bool = false
    var syncExtensiveChangesInProgress: Bool = false
    var signalVisibilityMigrationInProgress: Bool = false
    var temperatureUnit: TemperatureUnit = .celsius
    var temperatureAccuracy: MeasurementAccuracyType = .two
    var humidityUnit: HumidityUnit = .percent
    var humidityAccuracy: MeasurementAccuracyType = .two
    var relativeHumidityAccuracy: MeasurementAccuracyType = .two
    var absoluteHumidityAccuracy: MeasurementAccuracyType = .two
    var dewPointAccuracy: MeasurementAccuracyType = .two
    var pressureUnit: UnitPressure = .hectopascals
    var pressureAccuracy: MeasurementAccuracyType = .two
    var pmAccuracy: MeasurementAccuracyType = .two
    var accelerationAccuracy: MeasurementAccuracyType = .two
    var voltageAccuracy: MeasurementAccuracyType = .two
    var welcomeShown: Bool = false
    var showGraphLongPressTutorial: Bool = false
    var tosAccepted: Bool = false
    var analyticsConsentGiven: Bool = false
    var tagChartsLandscapeSwipeInstructionWasShown: Bool = false
    var language: Language = .english
    var cloudProfileLanguageCode: String? = nil
    var isAdvertisementDaemonOn: Bool = false
    var advertisementDaemonIntervalMinutes: Int = 0
    var connectionTimeout: TimeInterval = 0
    var serviceTimeout: TimeInterval = 0
    var cardsSwipeHintWasShown: Bool = false
    var alertsMuteIntervalMinutes: Int = 0
    var movementAlertHysteresisMinutes: Int = 0
    var saveHeartbeats: Bool = false
    var saveHeartbeatsIntervalMinutes: Int = 0
    var saveHeartbeatsForegroundIntervalSeconds: Int = 0
    var webPullIntervalMinutes: Int = 0
    var dataPruningOffsetHours: Int = 240
    var chartIntervalSeconds: Int = 0
    var chartDurationHours: Int = 48
    var chartDownsamplingOn: Bool = false
    var chartShowAllMeasurements: Bool = true
    var chartDrawDotsOn: Bool = false
    var chartStatsOn: Bool = false
    var chartShowAll: Bool = false
    var networkPullIntervalSeconds: Int = 0
    var widgetRefreshIntervalMinutes: Int = 0
    var forceRefreshWidget: Bool = false
    var networkPruningIntervalHours: Int = 0
    var experimentalFeaturesEnabled: Bool = false
    var cloudModeEnabled: Bool = false
    var useSimpleWidget: Bool = false
    var appIsOnForeground: Bool = false
    var appOpenedCount: Int = 0
    var appOpenedInitialCountToAskReview: Int = 0
    var appOpenedCountDivisibleToAskReview: Int = 0
    var appStoreReviewLastRequestAppOpenedCount: Int = 0
    var dashboardEnabled: Bool = false
    var dashboardType: DashboardType = .image
    var dashboardTapActionType: DashboardTapActionType = .card
    var showFullSensorCardOnDashboardTap: Bool = false
    var dashboardSensorOrder: [String] = []
    var theme: RuuviTheme = .system
    var hideNFCForSensorContest: Bool = false
    var alertSound: RuuviAlertSound = .systemDefault
    var emailAlertDisabled: Bool = false
    var pushAlertDisabled: Bool = false
    var marketingPreference: Bool = false
    var limitAlertNotificationsEnabled: Bool = false
    var showSwitchStatusLabel: Bool = false
    var showAlertsRangeInGraph: Bool = true
    var useNewGraphRendering: Bool = false
    var imageCompressionQuality: Int = 80
    var chartsPerScreen: Int = 3
    var historySyncForEachSensor: Bool = false
    var includeDataSourceInHistoryExport: Bool = false
    var customTempAlertLowerBound: Double = 0
    var customTempAlertUpperBound: Double = 0
    private var values: [String: Any] = [:]
    private var movements: [String: Date] = [:]
    func movementAlertHysteresisLastEvents() -> [String: Date] { movements }
    func setMovementAlertHysteresisLastEvents(_ values: [String: Date]) { movements = values }
    func keepConnectionDialogWasShown(for luid: LocalIdentifier) -> Bool {
        values["connection." + luid.value] as? Bool ?? false
    }
    func setKeepConnectionDialogWasShown(_ value: Bool, for luid: LocalIdentifier) {
        values["connection." + luid.value] = value
    }
    func firmwareUpdateDialogWasShown(for luid: LocalIdentifier) -> Bool {
        values["firmware." + luid.value] as? Bool ?? false
    }
    func setFirmwareUpdateDialogWasShown(_ value: Bool, for luid: LocalIdentifier) {
        values["firmware." + luid.value] = value
    }
    func syncDialogHidden(for luid: LocalIdentifier) -> Bool { values["sync." + luid.value] as? Bool ?? false }
    func setSyncDialogHidden(_ value: Bool, for luid: LocalIdentifier) { values["sync." + luid.value] = value }
    func showCustomTempAlertBound(for id: String) -> Bool { values["temp." + id] as? Bool ?? false }
    func setShowCustomTempAlertBound(_ value: Bool, for id: String) { values["temp." + id] = value }
    func showCustomCO2AlertBound(for id: String) -> Bool { values["co2." + id] as? Bool ?? false }
    func setShowCustomCO2AlertBound(_ value: Bool, for id: String) { values["co2." + id] = value }
    func showCustomPMAlertBound(for id: String) -> Bool { values["pm." + id] as? Bool ?? false }
    func setShowCustomPMAlertBound(_ value: Bool, for id: String) { values["pm." + id] = value }
    func cardToOpenFromWidget() -> String? { values["widget"] as? String }
    func setCardToOpenFromWidget(for macId: String?) { values["widget"] = macId }
    func lastOpenedChart() -> String? { values["chart"] as? String }
    func setLastOpenedChart(with id: String?) { values["chart"] = id }
    func setOwnerCheckDate(for macId: MACIdentifier?, value: Date?) { values["owner." + (macId?.value ?? "")] = value }
    func ownerCheckDate(for macId: MACIdentifier?) -> Date? { values["owner." + (macId?.value ?? "")] as? Date }
    func ledBrightnessSelection(for macId: MACIdentifier?) -> RuuviLedBrightnessLevel? {
        values["led." + (macId?.value ?? "")] as? RuuviLedBrightnessLevel
    }
    func setLedBrightnessSelection(_ selection: RuuviLedBrightnessLevel?, for macId: MACIdentifier?) {
        values["led." + (macId?.value ?? "")] = selection
    }
    func setNotificationsBadgeCount(value: Int) { values["badge"] = value }
    func notificationsBadgeCount() -> Int { values["badge"] as? Int ?? 0 }
    func dashboardSignInBannerHidden(for version: String) -> Bool { values["banner." + version] as? Bool ?? false }
    func setDashboardSignInBannerHidden(for version: String) { values["banner." + version] = true }
    var resetCount = 0
    func resetCloudProfileSettings() { resetCount += 1 }
}
