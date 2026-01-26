// swiftlint:disable file_length
import Foundation
import UIKit
import RuuviLocal
import RuuviOntology
import RuuviService
import WidgetKit

protocol DashboardSettingsServiceDelegate: AnyObject {
    func settingsService(
        _ service: DashboardSettingsService,
        dashboardTypeDidChange type: DashboardType
    )
    func settingsService(
        _ service: DashboardSettingsService,
        dashboardTapActionDidChange type: DashboardTapActionType
    )
    func settingsService(
        _ service: DashboardSettingsService,
        sensorOrderDidChange: Bool
    )
    func settingsService(
        _ service: DashboardSettingsService,
        measurementUnitsDidChange: Bool
    )
    func settingsService(
        _ service: DashboardSettingsService,
        calibrationSettingsDidChange: Bool
    )
    func settingsService(
        _ service: DashboardSettingsService,
        languageDidChange: Bool
    )
}

class DashboardSettingsService {

    // MARK: - Dependencies
    private let ruuviAppSettingsService: RuuviServiceAppSettings

    private var settings: RuuviLocalSettings

    // MARK: - Properties
    weak var delegate: DashboardSettingsServiceDelegate?

    private var isActivelyDraggingCards: Bool = false

    // MARK: - App Group
    private let appGroupDefaults = UserDefaults(suiteName: AppGroupConstants.appGroupSuiteIdentifier)

    // MARK: - Observation Tokens
    private var temperatureUnitToken: NSObjectProtocol?
    private var temperatureAccuracyToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var humidityAccuracyToken: NSObjectProtocol?
    private var pressureUnitToken: NSObjectProtocol?
    private var pressureAccuracyToken: NSObjectProtocol?
    private var languageToken: NSObjectProtocol?
    private var widgetRefreshIntervalToken: NSObjectProtocol?
    private var systemLanguageChangeToken: NSObjectProtocol?
    private var calibrationSettingsToken: NSObjectProtocol?
    private var dashboardTypeToken: NSObjectProtocol?
    private var dashboardTapActionTypeToken: NSObjectProtocol?
    private var sensorOrderChangeToken: NSObjectProtocol?

    // MARK: - Initialization
    init(
        settings: RuuviLocalSettings,
        ruuviAppSettingsService: RuuviServiceAppSettings
    ) {
        self.settings = settings
        self.ruuviAppSettingsService = ruuviAppSettingsService
    }

    deinit {
        stopObservingSettings()
    }

    // MARK: - Public Interface
    func startObservingSettings() {
        observeMeasurementUnitSettings()
        observeDashboardSettings()
        observeCalibrationSettings()
        observeLanguageSettings()
        observeSensorOrderSettings()
    }

    func stopObservingSettings() {
        let tokens = [
            temperatureUnitToken, temperatureAccuracyToken,
            humidityUnitToken, humidityAccuracyToken,
            pressureUnitToken, pressureAccuracyToken,
            languageToken, widgetRefreshIntervalToken,
            systemLanguageChangeToken, calibrationSettingsToken,
            dashboardTypeToken, dashboardTapActionTypeToken,
            sensorOrderChangeToken,
        ]

        tokens.forEach { $0?.invalidate() }

        temperatureUnitToken = nil
        temperatureAccuracyToken = nil
        humidityUnitToken = nil
        humidityAccuracyToken = nil
        pressureUnitToken = nil
        pressureAccuracyToken = nil
        languageToken = nil
        widgetRefreshIntervalToken = nil
        systemLanguageChangeToken = nil
        calibrationSettingsToken = nil
        dashboardTypeToken = nil
        dashboardTapActionTypeToken = nil
        sensorOrderChangeToken = nil
    }

    func syncAppSettingsToAppGroupContainer(isAuthorized: Bool) {
        syncAuthorizationStatus(isAuthorized)
        syncMeasurementUnits()
        syncWidgetSettings()
        reloadWidgets()
    }

    func updateDashboardType(_ type: DashboardType) {
        settings.dashboardType = type
        syncCloudSetting { service in
            _ = try await service.set(dashboardType: type)
        }
    }

    func updateDashboardTapAction(_ type: DashboardTapActionType) {
        settings.dashboardTapActionType = type
        syncCloudSetting { service in
            _ = try await service.set(dashboardTapActionType: type)
        }
    }

    func updateShowFullSensorCardOnDashboardTap(_ show: Bool) {
        settings.showFullSensorCardOnDashboardTap = show
    }

    func updateSensorOrder(_ orderedIds: [String]) {
        settings.dashboardSensorOrder = orderedIds
        syncCloudSetting { service in
            _ = try await service.set(dashboardSensorOrder: orderedIds)
        }
    }

    func resetSensorOrder() {
        settings.dashboardSensorOrder = []
        syncCloudSetting { service in
            _ = try await service.set(dashboardSensorOrder: [])
        }
    }

    func getCurrentDashboardSortingType() -> DashboardSortingType {
        return settings.dashboardSensorOrder.isEmpty ? .alphabetical : .manual
    }

    func setSensorOrderResetNeeded() {
        delegate?.settingsService(self, sensorOrderDidChange: true)
    }

    func askAppStoreReview(with sensorsCount: Int) {
        guard let dayDifference = Calendar.current.dateComponents(
            [.day],
            from: FileManager().appInstalledDate,
            to: Date()
        ).day, dayDifference > 7, sensorsCount > 0 else { return }

        AppStoreReviewHelper.askForReview(settings: settings)
    }

    func setUserActivelyDraggingCards(_ value: Bool) {
        isActivelyDraggingCards = value
    }

    func setKeepConnectionDialogWasShown(for snapshot: RuuviTagCardSnapshot) {
        if let luid = snapshot.identifierData.luid {
            settings.setKeepConnectionDialogWasShown(true, for: luid)
        }
    }

    func keepConnectionDialogWasShown(for snapshot: RuuviTagCardSnapshot) -> Bool {
        if let luid = snapshot.identifierData.luid {
            return settings.keepConnectionDialogWasShown(for: luid)
        }
        return false
    }
}

// MARK: - Private Implementation
private extension DashboardSettingsService {

    func observeMeasurementUnitSettings() {
        temperatureUnitToken = NotificationCenter.default.addObserver(
            forName: .TemperatureUnitDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMeasurementUnitChange()
        }

        temperatureAccuracyToken = NotificationCenter.default.addObserver(
            forName: .TemperatureAccuracyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMeasurementUnitChange()
        }

        humidityUnitToken = NotificationCenter.default.addObserver(
            forName: .HumidityUnitDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMeasurementUnitChange()
        }

        humidityAccuracyToken = NotificationCenter.default.addObserver(
            forName: .HumidityAccuracyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMeasurementUnitChange()
        }

        pressureUnitToken = NotificationCenter.default.addObserver(
            forName: .PressureUnitDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMeasurementUnitChange()
        }

        pressureAccuracyToken = NotificationCenter.default.addObserver(
            forName: .PressureUnitAccuracyChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMeasurementUnitChange()
        }

        widgetRefreshIntervalToken = NotificationCenter.default.addObserver(
            forName: .WidgetRefreshIntervalDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncWidgetSettings()
            self?.reloadWidgets()
        }
    }

    func observeDashboardSettings() {
        dashboardTypeToken = NotificationCenter.default.addObserver(
            forName: .DashboardTypeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let userInfo = notification.userInfo,
               let type = userInfo[DashboardTypeKey.type] as? DashboardType {
                self.delegate?.settingsService(self, dashboardTypeDidChange: type)
            }
        }

        dashboardTapActionTypeToken = NotificationCenter.default.addObserver(
            forName: .DashboardTapActionTypeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let userInfo = notification.userInfo,
               let type = userInfo[DashboardTapActionTypeKey.type] as? DashboardTapActionType {
                self.delegate?.settingsService(self, dashboardTapActionDidChange: type)
            }
        }
    }

    func observeCalibrationSettings() {
        calibrationSettingsToken = NotificationCenter.default.addObserver(
            forName: .SensorCalibrationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.settingsService(self, calibrationSettingsDidChange: true)
        }
    }

    func observeLanguageSettings() {
        languageToken = NotificationCenter.default.addObserver(
            forName: .LanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLanguageChange()
        }

        systemLanguageChangeToken = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLanguageChange()
        }
    }

    func observeSensorOrderSettings() {
        sensorOrderChangeToken = NotificationCenter.default.addObserver(
            forName: .DashboardSensorOrderDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            guard !self.isActivelyDraggingCards else { return }
            self.delegate?.settingsService(self, sensorOrderDidChange: true)
        }
    }

    func handleMeasurementUnitChange() {
        syncMeasurementUnits()
        reloadWidgets()
        delegate?.settingsService(self, measurementUnitsDidChange: true)
    }

    func handleLanguageChange() {
        syncMeasurementUnits()
        reloadWidgets()
        delegate?.settingsService(self, languageDidChange: true)
    }
}

private extension DashboardSettingsService {
    func syncCloudSetting(
        _ update: @escaping (RuuviServiceAppSettings) async throws -> Void
    ) {
        let service = ruuviAppSettingsService
        Task {
            try? await update(service)
        }
    }
}

// MARK: - App Group Synchronization
private extension DashboardSettingsService {

    func syncAuthorizationStatus(_ isAuthorized: Bool) {
        appGroupDefaults?.set(isAuthorized, forKey: AppGroupConstants.isAuthorizedUDKey)
    }

    func syncMeasurementUnits() {
        syncTemperatureUnit()
        syncHumidityUnit()
        syncPressureUnit()
    }

    func syncTemperatureUnit() {
        var temperatureUnitInt = 2
        switch settings.temperatureUnit {
        case .kelvin:
            temperatureUnitInt = 1
        case .celsius:
            temperatureUnitInt = 2
        case .fahrenheit:
            temperatureUnitInt = 3
        }

        appGroupDefaults?.set(temperatureUnitInt, forKey: AppGroupConstants.temperatureUnitKey)
        appGroupDefaults?.set(settings.temperatureAccuracy.value, forKey: AppGroupConstants.temperatureAccuracyKey)
    }

    func syncHumidityUnit() {
        var humidityUnitInt = 0
        switch settings.humidityUnit {
        case .percent:
            humidityUnitInt = 0
        case .gm3:
            humidityUnitInt = 1
        case .dew:
            humidityUnitInt = 2
        }

        appGroupDefaults?.set(humidityUnitInt, forKey: AppGroupConstants.humidityUnitKey)
        appGroupDefaults?.set(
            settings.humidityAccuracy.value,
            forKey: AppGroupConstants.humidityAccuracyKey
        )
    }

    func syncPressureUnit() {
        appGroupDefaults?.set(settings.pressureUnit.hashValue, forKey: AppGroupConstants.pressureUnitKey)
        appGroupDefaults?.set(settings.pressureAccuracy.value, forKey: AppGroupConstants.pressureAccuracyKey)
    }

    func syncWidgetSettings() {
        appGroupDefaults?.set(
            settings.widgetRefreshIntervalMinutes,
            forKey: AppGroupConstants.widgetRefreshIntervalKey
        )

        appGroupDefaults?.set(
            settings.forceRefreshWidget,
            forKey: AppGroupConstants.forceRefreshWidgetKey
        )
    }

    func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: AppAssemblyConstants.simpleWidgetKindId)
    }
}

// MARK: - Settings Accessors
extension DashboardSettingsService {

    func getDashboardType() -> DashboardType {
        return settings.dashboardType
    }

    func getDashboardTapActionType() -> DashboardTapActionType {
        return settings.dashboardTapActionType
    }

    func showFullSensorCardOnDashboardTap() -> Bool {
        return settings.showFullSensorCardOnDashboardTap
    }

    func getSensorOrder() -> [String] {
        return settings.dashboardSensorOrder
    }
}

// MARK: - Cloud Sensor Utilities
extension DashboardSettingsService {

    func syncHasCloudSensorToAppGroupContainer(hasCloudSensors: Bool) {
        appGroupDefaults?.set(hasCloudSensors, forKey: AppGroupConstants.hasCloudSensorsKey)
        appGroupDefaults?.synchronize()
    }

    func shouldShowSignInBanner(isAuthorized: Bool, sensorCount: Int) -> Bool {
        guard let currentAppVersion = getCurrentAppVersion() else { return false }

        return settings.signedInAtleastOnce &&
        !isAuthorized &&
        sensorCount > 0 &&
        !settings.dashboardSignInBannerHidden(for: currentAppVersion)
    }

    func hideSignInBanner() {
        if let currentAppVersion = getCurrentAppVersion() {
            settings.setDashboardSignInBannerHidden(for: currentAppVersion)
        }
    }

    private func getCurrentAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

// swiftlint:enable file_length
