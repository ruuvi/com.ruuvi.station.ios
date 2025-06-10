import Foundation
import RuuviOntology
import RuuviLocal
import RuuviUser

protocol ViewModelManagementServiceProtocol: AnyObject {
    var viewModels: [CardsViewModel] { get }
    var showSignInBanner: Bool { get }
    var noSensorsMessage: Bool { get }
    
    var onViewModelsChanged: (([CardsViewModel]) -> Void)? { get set }
    var onSingleViewModelChanged: ((CardsViewModel) -> Void)? { get set }
    var onSignInBannerVisibilityChanged: ((Bool) -> Void)? { get set }
    var onNoSensorsMessageChanged: ((Bool) -> Void)? { get set }
    
    func updateViewModels(
        sensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        connectionStates: [String: Bool],
        syncStates: [String: NetworkSyncStatus?]
    )
    func updateSingleViewModel(
        for sensorId: String,
        with record: RuuviTagSensorRecord?,
        sensorSettings: SensorSettings?
    )
    func updateSingleViewModelConnection(for sensorId: String, isConnected: Bool)
    func updateSingleViewModelSettings(for sensorId: String, settings: SensorSettings?)
    func reorderSensors(with type: DashboardSortingType, orderedIds: [String])
    func updateSensorName(_ name: String, for sensorId: String)
    func processLatestRecord(_ record: RuuviTagSensorRecord?, for sensorId: String)
    func updateAlertStates(for sensorId: String, alertStates: [AlertType: AlertState])
    func shouldShowSignInBanner() -> Bool
    func loadBackgroundImages(for sensors: [AnyRuuviTagSensor])
}

final class ViewModelManagementService: ViewModelManagementServiceProtocol {
    // MARK: - Dependencies
    private let settings: RuuviLocalSettings
    private let ruuviUser: RuuviUser
    private let sensorDataService: SensorDataServiceProtocol
    
    // MARK: - Private Properties
    private var _viewModels: [CardsViewModel] = []
    private var _showSignInBanner: Bool = false
    private var _noSensorsMessage: Bool = false
    
    private var didLoadInitialSensors = false
    
    // MARK: - Public Properties
    var viewModels: [CardsViewModel] {
        return _viewModels
    }
    
    var showSignInBanner: Bool {
        return _showSignInBanner
    }
    
    var noSensorsMessage: Bool {
        return _noSensorsMessage
    }
    
    var onViewModelsChanged: (([CardsViewModel]) -> Void)?
    var onSingleViewModelChanged: ((CardsViewModel) -> Void)?
    var onSignInBannerVisibilityChanged: ((Bool) -> Void)?
    var onNoSensorsMessageChanged: ((Bool) -> Void)?
    
    // MARK: - Initialization
    init(
        settings: RuuviLocalSettings,
        ruuviUser: RuuviUser,
        sensorDataService: SensorDataServiceProtocol
    ) {
        self.settings = settings
        self.ruuviUser = ruuviUser
        self.sensorDataService = sensorDataService
    }
    
    // MARK: - Public Methods
    func updateViewModels(
        sensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        connectionStates: [String: Bool],
        syncStates: [String: NetworkSyncStatus?]
    ) {
        let newViewModels = sensors.compactMap { sensor -> CardsViewModel in
            let viewModel = CardsViewModel(sensor)
            
            // Update connection state
            if let luid = sensor.luid {
                viewModel.isConnected = connectionStates[luid.value] ?? false
            } else if let macId = sensor.macId {
                viewModel.networkSyncStatus = (
                    syncStates[macId.value] ?? nil
                ) ?? .none
                viewModel.isConnected = false
            }
            
            // Apply sensor settings if available
            if let sensorSetting = sensorSettings.first(where: { $0.id == sensor.id }) {
                applySensorSettings(sensorSetting, to: viewModel)
            }
            
            return viewModel
        }
        
        let orderedViewModels = reorderViewModels(newViewModels)
        _viewModels = orderedViewModels
        onViewModelsChanged?(orderedViewModels)
        
        // Load background images for all sensors
        loadBackgroundImages(for: sensors)
        
        // Update UI state
        if didLoadInitialSensors {
            let noSensors = orderedViewModels.isEmpty
            _noSensorsMessage = noSensors
            onNoSensorsMessageChanged?(noSensors)
        }
        didLoadInitialSensors = true
        
        updateSignInBannerVisibility(sensorsCount: orderedViewModels.count)
    }
    
    func reorderSensors(with type: DashboardSortingType, orderedIds: [String]) {
        let reorderedViewModels: [CardsViewModel]
        
        switch type {
        case .manual:
            reorderedViewModels = reorderManually(_viewModels, orderedIds: orderedIds)
        case .alphabetical:
            reorderedViewModels = reorderAlphabetically(_viewModels)
        }
        
        _viewModels = reorderedViewModels
        onViewModelsChanged?(reorderedViewModels)
    }
    
    func updateSensorName(_ name: String, for sensorId: String) {
        if let index = _viewModels.firstIndex(where: { $0.id == sensorId }) {
            _viewModels[index].name = name
            
            // Use single view model update for performance
            onSingleViewModelChanged?(_viewModels[index])
        }
    }
    
    func processLatestRecord(_ record: RuuviTagSensorRecord?, for sensorId: String) {
        // Use optimized single view model update instead of full array update
        updateSingleViewModel(for: sensorId, with: record, sensorSettings: nil)
    }
    
    func updateAlertStates(for sensorId: String, alertStates: [AlertType: AlertState]) {
        if let index = _viewModels.firstIndex(where: { $0.id == sensorId }) {
            let viewModel = _viewModels[index]
            applyAlertStates(alertStates, to: viewModel)
            
            // Use single view model update for performance
            onSingleViewModelChanged?(viewModel)
        }
    }
    
    func shouldShowSignInBanner() -> Bool {
        guard let currentAppVersion = currentAppVersion() else { return false }
        
        return settings.signedInAtleastOnce && 
               !ruuviUser.isAuthorized &&
               !_viewModels.isEmpty &&
               !settings.dashboardSignInBannerHidden(for: currentAppVersion)
    }
    
    // MARK: - Private Methods
    private func reorderViewModels(_ viewModels: [CardsViewModel]) -> [CardsViewModel] {
        let sortedSensors = settings.dashboardSensorOrder
        
        if sortedSensors.isEmpty {
            return reorderAlphabetically(viewModels)
        } else {
            return reorderManually(viewModels, orderedIds: sortedSensors)
        }
    }
    
    private func reorderManually(_ viewModels: [CardsViewModel], orderedIds: [String]) -> [CardsViewModel] {
        return viewModels.sorted { (first, second) -> Bool in
            guard let firstMacId = first.mac?.value,
                  let secondMacId = second.mac?.value else { return false }
            let firstIndex = orderedIds.firstIndex(of: firstMacId) ?? Int.max
            let secondIndex = orderedIds.firstIndex(of: secondMacId) ?? Int.max
            return firstIndex < secondIndex
        }
    }
    
    private func reorderAlphabetically(_ viewModels: [CardsViewModel]) -> [CardsViewModel] {
        return viewModels.sorted { (first, second) -> Bool in
            let firstName = first.name.lowercased()
            let secondName = second.name.lowercased()
            return firstName < secondName
        }
    }
    
    private func applySensorSettings(_ settings: SensorSettings, to viewModel: CardsViewModel) {
        // Apply any sensor-specific settings to the view model
        // This could include custom names, calibration offsets, etc.
    }
    
    private func applyAlertStates(_ alertStates: [AlertType: AlertState], to viewModel: CardsViewModel) {
        for (alertType, alertState) in alertStates {
            switch alertType {
            case .temperature:
                viewModel.temperatureAlertState = alertState
            case .relativeHumidity:
                viewModel.relativeHumidityAlertState = alertState
            case .pressure:
                viewModel.pressureAlertState = alertState
            case .signal:
                viewModel.signalAlertState = alertState
            case .carbonDioxide:
                viewModel.carbonDioxideAlertState = alertState
            case .pMatter1:
                viewModel.pMatter1AlertState = alertState
            case .pMatter2_5:
                viewModel.pMatter2_5AlertState = alertState
            case .pMatter4:
                viewModel.pMatter4AlertState = alertState
            case .pMatter10:
                viewModel.pMatter10AlertState = alertState
            case .voc:
                viewModel.vocAlertState = alertState
            case .nox:
                viewModel.noxAlertState = alertState
            case .sound:
                viewModel.soundAlertState = alertState
            case .luminosity:
                viewModel.luminosityAlertState = alertState
            case .connection:
                viewModel.connectionAlertState = alertState
            case .movement:
                viewModel.movementAlertState = alertState
            case .cloudConnection:
                viewModel.cloudConnectionAlertState = alertState
            default:
                break
            }
        }
        
        updateOverallAlertState(for: viewModel)
    }
    
    private func updateOverallAlertState(for viewModel: CardsViewModel) {
        let alertStates = [
            viewModel.temperatureAlertState,
            viewModel.relativeHumidityAlertState,
            viewModel.pressureAlertState,
            viewModel.signalAlertState,
            viewModel.carbonDioxideAlertState,
            viewModel.pMatter1AlertState,
            viewModel.pMatter2_5AlertState,
            viewModel.pMatter4AlertState,
            viewModel.pMatter10AlertState,
            viewModel.vocAlertState,
            viewModel.noxAlertState,
            viewModel.soundAlertState,
            viewModel.luminosityAlertState,
            viewModel.connectionAlertState,
            viewModel.movementAlertState,
            viewModel.cloudConnectionAlertState,
        ]
        
        if alertStates.contains(.firing) {
            viewModel.alertState = .firing
        } else if alertStates.contains(.registered) {
            viewModel.alertState = .registered
        } else {
            viewModel.alertState = nil
        }
    }
    
    private func updateSignInBannerVisibility(sensorsCount: Int) {
        guard let currentAppVersion = currentAppVersion() else {
            _showSignInBanner = false
            onSignInBannerVisibilityChanged?(false)
            return
        }
        
        let shouldShow = settings.signedInAtleastOnce && 
                        !ruuviUser.isAuthorized &&
                        sensorsCount > 0 &&
                        !settings.dashboardSignInBannerHidden(for: currentAppVersion)
        
        _showSignInBanner = shouldShow
        onSignInBannerVisibilityChanged?(shouldShow)
    }
    
    private func currentAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    // MARK: - Optimized Single View Model Updates
    
    func updateSingleViewModel(
        for sensorId: String,
        with record: RuuviTagSensorRecord?,
        sensorSettings: SensorSettings?
    ) {
        guard let index = _viewModels.firstIndex(where: { $0.id == sensorId }) else {
            return
        }
        
        let viewModel = _viewModels[index]
        
        // Update the view model with new record
        if let record = record {
            let updatedRecord = record.with(sensorSettings: sensorSettings)
            viewModel.update(updatedRecord)
        }
        
        // Apply sensor settings if provided
        if let settings = sensorSettings {
            applySensorSettings(settings, to: viewModel)
        }
        
        // Trigger single view model update instead of full array update
        onSingleViewModelChanged?(viewModel)
    }
    
    func updateSingleViewModelConnection(for sensorId: String, isConnected: Bool) {
        guard let index = _viewModels.firstIndex(where: { $0.id == sensorId }) else {
            return
        }
        
        let viewModel = _viewModels[index]
        viewModel.isConnected = isConnected
        
        // Trigger single view model update
        onSingleViewModelChanged?(viewModel)
    }
    
    func updateSingleViewModelSettings(for sensorId: String, settings: SensorSettings?) {
        guard let index = _viewModels.firstIndex(where: { $0.id == sensorId }) else {
            return
        }
        
        let viewModel = _viewModels[index]
        
        if let settings = settings {
            applySensorSettings(settings, to: viewModel)
        }
        
        // Trigger single view model update
        onSingleViewModelChanged?(viewModel)
    }
    
    func loadBackgroundImages(for sensors: [AnyRuuviTagSensor]) {
        for sensor in sensors {
            Task {
                do {
                    let image = try await sensorDataService.getSensorImage(for: sensor)
                    
                    // Update the view model with the background image on the main thread
                    await MainActor.run {
                        if let index = _viewModels.firstIndex(where: { $0.id == sensor.id }) {
                            _viewModels[index].background = image
                            onViewModelsChanged?(_viewModels)
                        }
                    }
                } catch {
                    // Background image loading failed, but this is not critical
                    // The card will simply display without a background image
                    print("Failed to load background image for sensor \(sensor.id): \(error)")
                }
            }
        }
    }
}

// MARK: - DashboardSortingType
enum DashboardSortingType {
    case manual
    case alphabetical
}
