import Foundation
import CoreBluetooth
import RuuviOntology
import RuuviLocal
import RuuviUser
import BTKit

protocol DashboardServiceCoordinatorProtocol: AnyObject {
    var viewModels: [CardsViewModel] { get }
    var ruuviTags: [AnyRuuviTagSensor] { get }
    var shouldShowSignInBanner: Bool { get }
    var noSensorsMessage: Bool { get }
    var bluetoothState: BTScannerState { get }
    var cloudMode: Bool { get }
    var syncStatus: CloudSyncStatus { get }
    
    var onViewModelsChanged: (([CardsViewModel]) -> Void)? { get set }
    var onShouldShowSignInBannerChanged: ((Bool) -> Void)? { get set }
    var onNoSensorsMessageChanged: ((Bool) -> Void)? { get set }
    var onBluetoothStateChanged: ((BTScannerState) -> Void)? { get set }
    var onCloudModeChanged: ((Bool) -> Void)? { get set }
    var onSyncStatusChanged: ((CloudSyncStatus) -> Void)? { get set }
    
    func startServices()
    func stopServices()
    func refreshCloudSync()
    func isConnected(uuid: String) -> Bool
    func setKeepConnection(_ keepConnection: Bool, for luid: LocalIdentifier)
    func processAlert(record: RuuviTagSensorRecord, viewModel: CardsViewModel)
    func reorderSensors(with type: DashboardSortingType, orderedIds: [String])
    func updateSensorName(_ name: String, for sensorId: String)
}

final class DashboardServiceCoordinator: DashboardServiceCoordinatorProtocol {
    // MARK: - Services
    private let sensorDataService: SensorDataServiceProtocol
    private let alertManagementService: AlertManagementServiceProtocol
    private let cloudSyncService: CloudSyncServiceProtocol
    private let connectionService: ConnectionServiceProtocol
    private let settingsObservationService: SettingsObservationServiceProtocol
    private let viewModelManagementService: ViewModelManagementServiceProtocol
    
    // MARK: - Private Properties
    private var _viewModels: [CardsViewModel] = []
    private var _ruuviTags: [AnyRuuviTagSensor] = []
    private var _shouldShowSignInBanner: Bool = false
    private var _noSensorsMessage: Bool = false
    private var _bluetoothState: BTScannerState = .unknown
    private var _cloudMode: Bool = false
    private var _syncStatus: CloudSyncStatus = .idle
    
    // MARK: - Public Properties
    var viewModels: [CardsViewModel] {
        return _viewModels
    }

    var ruuviTags: [AnyRuuviTagSensor] {
        return _ruuviTags
    }

    var shouldShowSignInBanner: Bool {
        return _shouldShowSignInBanner
    }
    
    var noSensorsMessage: Bool {
        return _noSensorsMessage
    }
    
    var bluetoothState: BTScannerState {
        return _bluetoothState
    }
    
    var cloudMode: Bool {
        return _cloudMode
    }
    
    var syncStatus: CloudSyncStatus {
        return _syncStatus
    }
    
    var onViewModelsChanged: (([CardsViewModel]) -> Void)?
    var onShouldShowSignInBannerChanged: ((Bool) -> Void)?
    var onNoSensorsMessageChanged: ((Bool) -> Void)?
    var onBluetoothStateChanged: ((BTScannerState) -> Void)?
    var onCloudModeChanged: ((Bool) -> Void)?
    var onSyncStatusChanged: ((CloudSyncStatus) -> Void)?
    
    // MARK: - Initialization
    init(
        sensorDataService: SensorDataServiceProtocol,
        alertManagementService: AlertManagementServiceProtocol,
        cloudSyncService: CloudSyncServiceProtocol,
        connectionService: ConnectionServiceProtocol,
        settingsObservationService: SettingsObservationServiceProtocol,
        viewModelManagementService: ViewModelManagementServiceProtocol
    ) {
        self.sensorDataService = sensorDataService
        self.alertManagementService = alertManagementService
        self.cloudSyncService = cloudSyncService
        self.connectionService = connectionService
        self.settingsObservationService = settingsObservationService
        self.viewModelManagementService = viewModelManagementService
        
        setupServiceCoordination()
    }
    
    deinit {
        stopServices()
    }
    
    // MARK: - Public Methods
    func startServices() {
        sensorDataService.startObservingSensors()
        alertManagementService.startObservingAlerts()
        cloudSyncService.startObservingCloudSync()
        connectionService.startObservingConnections()
        settingsObservationService.startObservingSettings()
        
        // Trigger initial cloud sync if authorized
        Task {
            try? await cloudSyncService.triggerFullHistorySync()
        }
    }
    
    func stopServices() {
        sensorDataService.stopObservingSensors()
        alertManagementService.stopObservingAlerts()
        cloudSyncService.stopObservingCloudSync()
        connectionService.stopObservingConnections()
        settingsObservationService.stopObservingSettings()
    }
    
    func refreshCloudSync() {
        Task {
            try? await cloudSyncService.refreshImmediately()
        }
    }
    
    func isConnected(uuid: String) -> Bool {
        return connectionService.isConnected(uuid: uuid)
    }
    
    func setKeepConnection(_ keepConnection: Bool, for luid: LocalIdentifier) {
        connectionService.setKeepConnection(keepConnection, for: luid)
    }
    
    func processAlert(record: RuuviTagSensorRecord, viewModel: CardsViewModel) {
        alertManagementService.processAlert(record: record, viewModel: viewModel)
    }
    
    func reorderSensors(with type: DashboardSortingType, orderedIds: [String]) {
        viewModelManagementService.reorderSensors(with: type, orderedIds: orderedIds)
    }
    
    func updateSensorName(_ name: String, for sensorId: String) {
        viewModelManagementService.updateSensorName(name, for: sensorId)
    }
    
    // MARK: - Private Methods
    private func setupServiceCoordination() {
        // Initialize current values from services
        _viewModels = viewModelManagementService.viewModels
        _ruuviTags = sensorDataService.sensors
        _shouldShowSignInBanner = viewModelManagementService.showSignInBanner
        _noSensorsMessage = viewModelManagementService.noSensorsMessage
        _bluetoothState = connectionService.bluetoothState
        _cloudMode = cloudSyncService.cloudMode
        _syncStatus = cloudSyncService.syncStatus
        
        // Setup service callbacks to coordinate data flow
        setupSensorDataCoordination()
        setupAlertCoordination()
        setupConnectionCoordination()
        setupCloudSyncCoordination()
        setupSettingsCoordination()
        setupViewModelCoordination()
    }
    
    private func setupSensorDataCoordination() {
        sensorDataService.onSensorsChanged = { [weak self] sensors in
            self?.coordinateSensorDataUpdate()
            self?.observeLatestRecords(for: sensors)
        }
        
        sensorDataService.onSensorSettingsChanged = { [weak self] _ in
            self?.coordinateSensorDataUpdate()
        }
    }
    
    private func setupAlertCoordination() {
        alertManagementService.onAlertStateChanged = { [weak self] alertStates in
            for (sensorId, alerts) in alertStates {
                self?.viewModelManagementService.updateAlertStates(for: sensorId, alertStates: alerts)
            }
        }
    }
    
    private func setupConnectionCoordination() {
        connectionService.onBluetoothStateChanged = { [weak self] newState in
            self?._bluetoothState = newState
            self?.onBluetoothStateChanged?(newState)
        }
        
        connectionService.onConnectionStatusChanged = { [weak self] _ in
            self?.coordinateSensorDataUpdate()
        }
    }
    
    private func setupCloudSyncCoordination() {
        cloudSyncService.onCloudModeChanged = { [weak self] newMode in
            self?._cloudMode = newMode
            self?.onCloudModeChanged?(newMode)
        }
        
        cloudSyncService.onSyncStatusChanged = { [weak self] newStatus in
            self?._syncStatus = newStatus
            self?.onSyncStatusChanged?(newStatus)
        }
    }
    
    private func setupSettingsCoordination() {
        // Sync app settings when any setting changes
        let syncSettings = { [weak self] in
            self?.settingsObservationService.syncAppSettingsToAppGroupContainer()
        }
        
        settingsObservationService.onTemperatureUnitChanged = { _ in syncSettings() }
        settingsObservationService.onHumidityUnitChanged = { _ in syncSettings() }
        settingsObservationService.onPressureUnitChanged = { _ in syncSettings() }
        settingsObservationService.onDashboardTypeChanged = { _ in syncSettings() }
    }
    
    private func setupViewModelCoordination() {
        viewModelManagementService.onViewModelsChanged = { [weak self] newViewModels in
            self?._viewModels = newViewModels
            self?.onViewModelsChanged?(newViewModels)
        }
        
        viewModelManagementService.onSignInBannerVisibilityChanged = { [weak self] newValue in
            self?._shouldShowSignInBanner = newValue
            self?.onShouldShowSignInBannerChanged?(newValue)
        }
        
        viewModelManagementService.onNoSensorsMessageChanged = { [weak self] newValue in
            self?._noSensorsMessage = newValue
            self?.onNoSensorsMessageChanged?(newValue)
        }
    }
    
    private func coordinateSensorDataUpdate() {
        let sensors = sensorDataService.sensors
        let sensorSettings = sensorDataService.sensorSettings
        let connectionStates = connectionService.connectionStatus
        
        // Get sync states for all sensors
        let syncStates = sensors.reduce(into: [String: NetworkSyncStatus?]()) { result, sensor in
            if let macId = sensor.macId {
                result[macId.value] = cloudSyncService.getSyncStatus(for: macId)
            }
        }
        
        viewModelManagementService.updateViewModels(
            sensors: sensors,
            sensorSettings: sensorSettings,
            connectionStates: connectionStates,
            syncStates: syncStates
        )
    }
    
    private func observeLatestRecords(for sensors: [AnyRuuviTagSensor]) {
        for sensor in sensors {
            Task {
                do {
                    let record = try await sensorDataService.getLatestRecord(for: sensor)
                    await MainActor.run {
                        viewModelManagementService.processLatestRecord(record, for: sensor.id)
                    }
                } catch {
                    // Handle error if needed
                }
            }
        }
    }
}
