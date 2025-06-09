import Foundation
import RuuviOntology
import RuuviLocal
import RuuviUser

protocol ViewModelManagementServiceProtocol: AnyObject {
    var viewModels: [CardsViewModel] { get }
    var showSignInBanner: Bool { get }
    var noSensorsMessage: Bool { get }
    
    var onViewModelsChanged: (([CardsViewModel]) -> Void)? { get set }
    var onSignInBannerVisibilityChanged: ((Bool) -> Void)? { get set }
    var onNoSensorsMessageChanged: ((Bool) -> Void)? { get set }
    
    func updateViewModels(
        sensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        connectionStates: [String: Bool],
        syncStates: [String: NetworkSyncStatus?]
    )
    func reorderSensors(with type: DashboardSortingType, orderedIds: [String])
    func updateSensorName(_ name: String, for sensorId: String)
    func processLatestRecord(_ record: RuuviTagSensorRecord?, for sensorId: String)
    func updateAlertStates(for sensorId: String, alertStates: [AlertType: AlertState])
    func shouldShowSignInBanner() -> Bool
}

final class ViewModelManagementService: ViewModelManagementServiceProtocol {
    // MARK: - Dependencies
    private let settings: RuuviLocalSettings
    private let ruuviUser: RuuviUser
    
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
    var onSignInBannerVisibilityChanged: ((Bool) -> Void)?
    var onNoSensorsMessageChanged: ((Bool) -> Void)?
    
    // MARK: - Initialization
    init(
        settings: RuuviLocalSettings,
        ruuviUser: RuuviUser
    ) {
        self.settings = settings
        self.ruuviUser = ruuviUser
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
            onViewModelsChanged?(_viewModels)
        }
    }
    
    func processLatestRecord(_ record: RuuviTagSensorRecord?, for sensorId: String) {
        if let index = _viewModels.firstIndex(where: { $0.id == sensorId }),
           let record = record {
            _viewModels[index].update(record)
            onViewModelsChanged?(_viewModels)
        }
    }
    
    func updateAlertStates(for sensorId: String, alertStates: [AlertType: AlertState]) {
        if let index = _viewModels.firstIndex(where: { $0.id == sensorId }) {
            applyAlertStates(alertStates, to: _viewModels[index])
            onViewModelsChanged?(_viewModels)
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
//        let shouldShow = shouldShowSignInBanner()
//        shouldShowSignInBannerSubject.send(shouldShow)
    }
    
    private func currentAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

// MARK: - DashboardSortingType
enum DashboardSortingType {
    case manual
    case alphabetical
}
