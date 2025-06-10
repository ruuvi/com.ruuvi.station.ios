import Foundation
import CoreBluetooth
import RuuviOntology
import RuuviLocal
import RuuviUser
import BTKit

protocol DashboardServiceCoordinatorProtocol: AnyObject {
    var viewModels: [CardsViewModel] { get }
    var ruuviTags: [AnyRuuviTagSensor] { get }
    var sensorSettings: [SensorSettings] { get }
    var shouldShowSignInBanner: Bool { get }
    var noSensorsMessage: Bool { get }
    var bluetoothState: BTScannerState { get }
    var cloudMode: Bool { get }
    var syncStatus: CloudSyncStatus { get }
    
    var onViewModelsChanged: (([CardsViewModel]) -> Void)? { get set }
    var onSingleViewModelChanged: ((CardsViewModel) -> Void)? { get set }
    var onShouldShowSignInBannerChanged: ((Bool) -> Void)? { get set }
    var onNoSensorsMessageChanged: ((Bool) -> Void)? { get set }
    var onBluetoothStateChanged: ((BTScannerState) -> Void)? { get set }
    var onCloudModeChanged: ((Bool) -> Void)? { get set }
    var onSyncStatusChanged: ((CloudSyncStatus) -> Void)? { get set }
    var onDaemonError: ((Error) -> Void)? { get set }
    var onUniversalLinkReceived: ((UniversalLinkType) -> Void)? { get set }
    
    func startServices()
    func stopServices()
    func refreshCloudSync()
    func isConnected(uuid: String) -> Bool
    func setKeepConnection(_ keepConnection: Bool, for luid: LocalIdentifier)
    func processAlert(record: RuuviTagSensorRecord, viewModel: CardsViewModel)
    func reorderSensors(with type: DashboardSortingType, orderedIds: [String])
    func updateSensorName(_ name: String, for sensorId: String)
    func processUniversalLink(_ linkType: UniversalLinkType)
    func getSensor(for viewModel: CardsViewModel) -> AnyRuuviTagSensor?
    func getSensorSettings(for viewModel: CardsViewModel) -> SensorSettings?
}

final class DashboardServiceCoordinator: DashboardServiceCoordinatorProtocol {
    // MARK: - Services
    private let sensorDataService: SensorDataServiceProtocol
    private let alertManagementService: AlertManagementServiceProtocol
    private let cloudSyncService: CloudSyncServiceProtocol
    private let connectionService: ConnectionServiceProtocol
    private let settingsObservationService: SettingsObservationServiceProtocol
    private let viewModelManagementService: ViewModelManagementServiceProtocol
    private let daemonErrorService: DaemonErrorServiceProtocol
    private let universalLinkService: UniversalLinkServiceProtocol
    
    // MARK: - Private Properties
    private var _viewModels: [CardsViewModel] = []
    private var _ruuviTags: [AnyRuuviTagSensor] = []
    private var _sensorSettings: [SensorSettings] = []
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
    
    var sensorSettings: [SensorSettings] {
        return _sensorSettings
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
    var onSingleViewModelChanged: ((CardsViewModel) -> Void)?
    var onShouldShowSignInBannerChanged: ((Bool) -> Void)?
    var onNoSensorsMessageChanged: ((Bool) -> Void)?
    var onBluetoothStateChanged: ((BTScannerState) -> Void)?
    var onCloudModeChanged: ((Bool) -> Void)?
    var onSyncStatusChanged: ((CloudSyncStatus) -> Void)?
    var onDaemonError: ((Error) -> Void)?
    var onUniversalLinkReceived: ((UniversalLinkType) -> Void)?
    
    // MARK: - Initialization
    init(
        sensorDataService: SensorDataServiceProtocol,
        alertManagementService: AlertManagementServiceProtocol,
        cloudSyncService: CloudSyncServiceProtocol,
        connectionService: ConnectionServiceProtocol,
        settingsObservationService: SettingsObservationServiceProtocol,
        viewModelManagementService: ViewModelManagementServiceProtocol,
        daemonErrorService: DaemonErrorServiceProtocol,
        universalLinkService: UniversalLinkServiceProtocol
    ) {
        self.sensorDataService = sensorDataService
        self.alertManagementService = alertManagementService
        self.cloudSyncService = cloudSyncService
        self.connectionService = connectionService
        self.settingsObservationService = settingsObservationService
        self.viewModelManagementService = viewModelManagementService
        self.daemonErrorService = daemonErrorService
        self.universalLinkService = universalLinkService
        
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
        daemonErrorService.startObservingDaemonErrors()
        universalLinkService.startObservingUniversalLinks()
        
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
        daemonErrorService.stopObservingDaemonErrors()
        universalLinkService.stopObservingUniversalLinks()
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
    
    func processUniversalLink(_ linkType: UniversalLinkType) {
        universalLinkService.processUniversalLink(linkType)
    }
    
    func getSensor(for viewModel: CardsViewModel) -> AnyRuuviTagSensor? {
        return _ruuviTags.first { $0.id == viewModel.id }
    }
    
    func getSensorSettings(for viewModel: CardsViewModel) -> SensorSettings? {
        return _sensorSettings.first { settings in
            (settings.luid?.any != nil && settings.luid?.any == viewModel.luid) ||
            (settings.macId?.any != nil && settings.macId?.any == viewModel.mac)
        }
    }

    // MARK: - Private Methods
    private func setupServiceCoordination() {
        // Initialize current values from services
        _viewModels = viewModelManagementService.viewModels
        _ruuviTags = sensorDataService.sensors
        _sensorSettings = sensorDataService.sensorSettings
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
        setupDaemonErrorCoordination()
        setupUniversalLinkCoordination()
    }
    
    private func setupSensorDataCoordination() {
        sensorDataService.onSensorsChanged = { [weak self] sensors in
            self?._ruuviTags = sensors
            self?.coordinateSensorDataUpdate()
        }
        
        sensorDataService.onSensorSettingsChanged = { [weak self] sensorSettings in
            self?._sensorSettings = sensorSettings
            self?.coordinateSensorDataUpdate()
        }
        
        sensorDataService.onLatestRecordChanged = { [weak self] sensorId, record in
            guard let self = self, let record = record else { return }
            
//            // Find the corresponding sensor settings for this record
//            let sensorSettings = self._sensorSettings.first { settings in
//                (settings.luid?.any != nil && settings.luid?.any?.value == sensorId) ||
//                (settings.macId?.any != nil && settings.macId?.any?.value == sensorId)
//            }
            
            // Use optimized single view model update instead of full coordinateSensorDataUpdate
            self.viewModelManagementService.updateSingleViewModel(
                for: sensorId,
                with: record,
                sensorSettings: nil
            )
        }
        
        // Handle individual sensor settings changes for optimized updates
        sensorDataService.onSingleSensorSettingsChanged = { [weak self] sensorId, settings in
            guard let self = self else { return }
            self.viewModelManagementService.updateSingleViewModelSettings(
                for: sensorId,
                settings: settings
            )
        }
    }
    
    private func setupAlertCoordination() {
        alertManagementService.onAlertStateChanged = { [weak self] alertStates in
            for (sensorId, alerts) in alertStates {
                // Use optimized single view model update for alert states
                self?.viewModelManagementService.updateAlertStates(for: sensorId, alertStates: alerts)
            }
        }
    }
    
    private func setupConnectionCoordination() {
        connectionService.onBluetoothStateChanged = { [weak self] newState in
            self?._bluetoothState = newState
            self?.onBluetoothStateChanged?(newState)
        }
        
        connectionService.onConnectionStatusChanged = { [weak self] connectionStates in
            guard let self = self else { return }
            // Update connection states for individual sensors using optimized updates
            for (uuid, isConnected) in connectionStates {
                // Find sensor by UUID and update only that view model
                if let sensorId = self._ruuviTags.first(where: { 
                    $0.luid?.value == uuid || $0.macId?.value == uuid 
                })?.id {
                    self.viewModelManagementService.updateSingleViewModelConnection(
                        for: sensorId,
                        isConnected: isConnected
                    )
                }
            }
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
            
            // When sync completes successfully, trigger a data refresh to show updated records
            if case .success = newStatus {
                self?.coordinateSensorDataUpdate()
            }
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
        
        // Handle single view model updates for optimal performance
        viewModelManagementService.onSingleViewModelChanged = { [weak self] updatedViewModel in
            guard let self = self else { return }
            
            // Update the specific view model in our local array
            if let index = self._viewModels.firstIndex(where: { $0.id == updatedViewModel.id }) {
                self._viewModels[index] = updatedViewModel
            }
            
            // Trigger single view model update callback for optimized UI updates
            self.onSingleViewModelChanged?(updatedViewModel)
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
    
    private func setupDaemonErrorCoordination() {
        daemonErrorService.onDaemonError = { [weak self] error in
            self?.onDaemonError?(error)
        }
    }
    
    private func setupUniversalLinkCoordination() {
        universalLinkService.onUniversalLinkReceived = { [weak self] linkType in
            self?.onUniversalLinkReceived?(linkType)
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
}
