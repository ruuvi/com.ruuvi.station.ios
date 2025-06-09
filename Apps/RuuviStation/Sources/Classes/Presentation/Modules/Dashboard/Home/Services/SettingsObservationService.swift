import Foundation
import RuuviLocal
import RuuviService
import WidgetKit
import Humidity
import RuuviOntology

protocol SettingsObservationServiceProtocol: AnyObject {
    var temperatureUnit: TemperatureUnit { get }
    var humidityUnit: HumidityUnit { get }
    var pressureUnit: UnitPressure { get }
    var dashboardType: DashboardType { get }
    var dashboardTapAction: DashboardTapActionType { get }
    var sensorOrder: [String] { get }
    
    var onTemperatureUnitChanged: ((TemperatureUnit) -> Void)? { get set }
    var onHumidityUnitChanged: ((HumidityUnit) -> Void)? { get set }
    var onPressureUnitChanged: ((UnitPressure) -> Void)? { get set }
    var onDashboardTypeChanged: ((DashboardType) -> Void)? { get set }
    var onDashboardTapActionChanged: ((DashboardTapActionType) -> Void)? { get set }
    var onSensorOrderChanged: (([String]) -> Void)? { get set }
    
    func startObservingSettings()
    func stopObservingSettings()
    func syncAppSettingsToAppGroupContainer()
}

final class SettingsObservationService: SettingsObservationServiceProtocol {
    // MARK: - Dependencies
    private let settings: RuuviLocalSettings
    private let ruuviAppSettingsService: RuuviServiceAppSettings
    
    // MARK: - Private Properties
    private var _temperatureUnit: TemperatureUnit = .celsius
    private var _humidityUnit: HumidityUnit = .percent
    private var _pressureUnit: UnitPressure = .hectopascals
    private var _dashboardType: DashboardType = .simple
    private var _dashboardTapAction: DashboardTapActionType = .card
    private var _sensorOrder: [String] = []
    
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
    
    private let appGroupDefaults = UserDefaults(
        suiteName: AppGroupConstants.appGroupSuiteIdentifier
    )
    
    // MARK: - Public Properties
    var temperatureUnit: TemperatureUnit {
        return _temperatureUnit
    }
    
    var humidityUnit: HumidityUnit {
        return _humidityUnit
    }
    
    var pressureUnit: UnitPressure {
        return _pressureUnit
    }
    
    var dashboardType: DashboardType {
        return _dashboardType
    }
    
    var dashboardTapAction: DashboardTapActionType {
        return _dashboardTapAction
    }
    
    var sensorOrder: [String] {
        return _sensorOrder
    }
    
    var onTemperatureUnitChanged: ((TemperatureUnit) -> Void)?
    var onHumidityUnitChanged: ((HumidityUnit) -> Void)?
    var onPressureUnitChanged: ((UnitPressure) -> Void)?
    var onDashboardTypeChanged: ((DashboardType) -> Void)?
    var onDashboardTapActionChanged: ((DashboardTapActionType) -> Void)?
    var onSensorOrderChanged: (([String]) -> Void)?
    
    // MARK: - Initialization
    init(
        settings: RuuviLocalSettings,
        ruuviAppSettingsService: RuuviServiceAppSettings
    ) {
        self.settings = settings
        self.ruuviAppSettingsService = ruuviAppSettingsService
        
        // Initialize current values
        _temperatureUnit = settings.temperatureUnit
        _humidityUnit = settings.humidityUnit
        _pressureUnit = settings.pressureUnit
        _dashboardType = settings.dashboardType
        _dashboardTapAction = settings.dashboardTapActionType
        _sensorOrder = settings.dashboardSensorOrder
    }
    
    deinit {
        stopObservingSettings()
    }
    
    // MARK: - Public Methods
    func startObservingSettings() {
        observeTemperatureSettings()
        observeHumiditySettings()
        observePressureSettings()
        observeLanguageSettings()
        observeWidgetSettings()
        observeCalibrationSettings()
        observeDashboardSettings()
        observeSensorOrderChanges()
    }
    
    func stopObservingSettings() {
        temperatureUnitToken?.invalidate()
        temperatureAccuracyToken?.invalidate()
        humidityUnitToken?.invalidate()
        humidityAccuracyToken?.invalidate()
        pressureUnitToken?.invalidate()
        pressureAccuracyToken?.invalidate()
        languageToken?.invalidate()
        widgetRefreshIntervalToken?.invalidate()
        systemLanguageChangeToken?.invalidate()
        calibrationSettingsToken?.invalidate()
        dashboardTypeToken?.invalidate()
        dashboardTapActionTypeToken?.invalidate()
        sensorOrderChangeToken?.invalidate()
    }
    
    func syncAppSettingsToAppGroupContainer() {
        syncTemperatureSettings()
        syncHumiditySettings()
        syncPressureSettings()
        syncWidgetSettings()
        reloadWidget()
    }
    
    // MARK: - Private Methods
    private func observeTemperatureSettings() {
        temperatureUnitToken = NotificationCenter.default.addObserver(
            forName: .TemperatureUnitDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let unit = self.settings.temperatureUnit
            self._temperatureUnit = unit
            self.onTemperatureUnitChanged?(unit)
            self.syncTemperatureSettings()
        }
        
        temperatureAccuracyToken = NotificationCenter.default.addObserver(
            forName: .TemperatureAccuracyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncTemperatureSettings()
        }
    }
    
    private func observeHumiditySettings() {
        humidityUnitToken = NotificationCenter.default.addObserver(
            forName: .HumidityUnitDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let unit = self.settings.humidityUnit
            self._humidityUnit = unit
            self.onHumidityUnitChanged?(unit)
            self.syncHumiditySettings()
        }
        
        humidityAccuracyToken = NotificationCenter.default.addObserver(
            forName: .HumidityAccuracyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncHumiditySettings()
        }
    }
    
    private func observePressureSettings() {
        pressureUnitToken = NotificationCenter.default.addObserver(
            forName: .PressureUnitDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let unit = self.settings.pressureUnit
            self._pressureUnit = unit
            self.onPressureUnitChanged?(unit)
            self.syncPressureSettings()
        }
        
        pressureAccuracyToken = NotificationCenter.default.addObserver(
            forName: .PressureAccuracyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncPressureSettings()
        }
    }
    
    private func observeLanguageSettings() {
        languageToken = NotificationCenter.default.addObserver(
            forName: .LanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncAppSettingsToAppGroupContainer()
        }
        
        systemLanguageChangeToken = NotificationCenter.default.addObserver(
            forName: .SystemLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncAppSettingsToAppGroupContainer()
        }
    }
    
    private func observeWidgetSettings() {
        widgetRefreshIntervalToken = NotificationCenter.default.addObserver(
            forName: .WidgetRefreshIntervalDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncWidgetSettings()
            self?.reloadWidget()
        }
    }
    
    private func observeCalibrationSettings() {
        calibrationSettingsToken = NotificationCenter.default.addObserver(
            forName: .CalibrationSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncAppSettingsToAppGroupContainer()
        }
    }
    
    private func observeDashboardSettings() {
        dashboardTypeToken = NotificationCenter.default.addObserver(
            forName: .DashboardTypeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let type = self.settings.dashboardType
            self._dashboardType = type
            self.onDashboardTypeChanged?(type)
        }
        
        dashboardTapActionTypeToken = NotificationCenter.default.addObserver(
            forName: .DashboardTapActionTypeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let type = self.settings.dashboardTapActionType
            self._dashboardTapAction = type
            self.onDashboardTapActionChanged?(type)
        }
    }
    
    private func observeSensorOrderChanges() {
        sensorOrderChangeToken = NotificationCenter.default.addObserver(
            forName: .SensorOrderDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let order = self.settings.dashboardSensorOrder
            self._sensorOrder = order
            self.onSensorOrderChanged?(order)
        }
    }
    
    private func syncTemperatureSettings() {
        var temperatureUnitInt = 2
        switch settings.temperatureUnit {
        case .kelvin:
            temperatureUnitInt = 1
        case .celsius:
            temperatureUnitInt = 2
        case .fahrenheit:
            temperatureUnitInt = 3
        }
        appGroupDefaults?.set(
            temperatureUnitInt,
            forKey: AppGroupConstants.temperatureUnitKey
        )
        
        appGroupDefaults?.set(
            settings.temperatureAccuracy.value,
            forKey: AppGroupConstants.temperatureAccuracyKey
        )
    }
    
    private func syncHumiditySettings() {
        var humidityUnitInt = 0
        switch settings.humidityUnit {
        case .percent:
            humidityUnitInt = 0
        case .gm3:
            humidityUnitInt = 1
        case .dew:
            humidityUnitInt = 2
        }
        appGroupDefaults?.set(
            humidityUnitInt,
            forKey: AppGroupConstants.humidityUnitKey
        )
        
        appGroupDefaults?.set(
            settings.humidityAccuracy.value,
            forKey: AppGroupConstants.humidityAccuracyKey
        )
    }
    
    private func syncPressureSettings() {
        appGroupDefaults?.set(
            settings.pressureUnit.hashValue,
            forKey: AppGroupConstants.pressureUnitKey
        )
        
        appGroupDefaults?.set(
            settings.pressureAccuracy.value,
            forKey: AppGroupConstants.pressureAccuracyKey
        )
    }
    
    private func syncWidgetSettings() {
        appGroupDefaults?.set(
            settings.widgetRefreshIntervalMinutes,
            forKey: AppGroupConstants.widgetRefreshIntervalKey
        )
        
        appGroupDefaults?.set(
            settings.forceRefreshWidget,
            forKey: AppGroupConstants.forceRefreshWidgetKey
        )
    }
    
    private func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(
            ofKind: AppAssemblyConstants.simpleWidgetKindId
        )
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let TemperatureUnitDidChange = Notification.Name("TemperatureUnitDidChange")
    static let TemperatureAccuracyDidChange = Notification.Name("TemperatureAccuracyDidChange")
    static let HumidityUnitDidChange = Notification.Name("HumidityUnitDidChange")
    static let HumidityAccuracyDidChange = Notification.Name("HumidityAccuracyDidChange")
    static let PressureUnitDidChange = Notification.Name("PressureUnitDidChange")
    static let PressureAccuracyDidChange = Notification.Name("PressureAccuracyDidChange")
    static let LanguageDidChange = Notification.Name("LanguageDidChange")
    static let SystemLanguageDidChange = Notification.Name("SystemLanguageDidChange")
    static let WidgetRefreshIntervalDidChange = Notification.Name("WidgetRefreshIntervalDidChange")
    static let CalibrationSettingsDidChange = Notification.Name("CalibrationSettingsDidChange")
    static let DashboardTypeDidChange = Notification.Name("DashboardTypeDidChange")
    static let DashboardTapActionTypeDidChange = Notification.Name("DashboardTapActionTypeDidChange")
    static let SensorOrderDidChange = Notification.Name("SensorOrderDidChange")
}
