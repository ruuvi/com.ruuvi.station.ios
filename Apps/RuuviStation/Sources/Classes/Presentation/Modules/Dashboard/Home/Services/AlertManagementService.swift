import Foundation
import RuuviOntology
import RuuviService
import RuuviNotifier

protocol AlertManagementServiceProtocol: AnyObject {
    var alertState: [String: [AlertType: AlertState]] { get }
    var onAlertStateChanged: (([String: [AlertType: AlertState]]) -> Void)? { get set }
    
    func startObservingAlerts()
    func stopObservingAlerts()
    func processAlert(record: RuuviTagSensorRecord, viewModel: CardsViewModel)
    func syncAlerts(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel)
    func getAlertBounds(for sensor: AnyRuuviTagSensor) -> (lower: Double?, upper: Double?)
}

final class AlertManagementService: AlertManagementServiceProtocol {
    // MARK: - Dependencies
    private let alertService: RuuviServiceAlert
    private let alertHandler: RuuviNotifier
    
    // MARK: - Private Properties
    private var _alertState: [String: [AlertType: AlertState]] = [:]
    private var alertDidChangeToken: NSObjectProtocol?
    
    // MARK: - Public Properties
    var alertState: [String: [AlertType: AlertState]] {
        return _alertState
    }
    
    var onAlertStateChanged: (([String: [AlertType: AlertState]]) -> Void)?
    
    // MARK: - Initialization
    init(
        alertService: RuuviServiceAlert,
        alertHandler: RuuviNotifier
    ) {
        self.alertService = alertService
        self.alertHandler = alertHandler
    }
    
    deinit {
        stopObservingAlerts()
    }
    
    // MARK: - Public Methods
    func startObservingAlerts() {
        alertDidChangeToken = NotificationCenter.default.addObserver(
            forName: .RuuviServiceAlertDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAlertChange(notification)
        }
    }
    
    func stopObservingAlerts() {
        alertDidChangeToken?.invalidate()
        alertDidChangeToken = nil
    }
    
    func processAlert(record: RuuviTagSensorRecord, viewModel: CardsViewModel) {
        if viewModel.isCloud,
           let macId = viewModel.mac {
            alertHandler.processNetwork(
                record: record,
                trigger: false,
                for: macId
            )
        } else {
            if viewModel.luid != nil {
                alertHandler.process(record: record, trigger: false)
            } else {
                guard let macId = viewModel.mac else { return }
                alertHandler.processNetwork(record: record, trigger: false, for: macId)
            }
        }
    }
    
    func syncAlerts(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        // Set alert bounds for humidity
        let (rhLower, rhUpper) = getAlertBounds(for: sensor)
        viewModel.rhAlertLowerBound = rhLower ?? 0
        viewModel.rhAlertUpperBound = rhUpper ?? 100
        
        // Sync all alert types with proper bounds and muted till
        syncTemperatureAlert(for: sensor, viewModel: viewModel)
        syncHumidityAlert(for: sensor, viewModel: viewModel)
        syncPressureAlert(for: sensor, viewModel: viewModel)
        syncSignalAlert(for: sensor, viewModel: viewModel)
        syncCarbonDioxideAlert(for: sensor, viewModel: viewModel)
        syncParticulateMatterAlerts(for: sensor, viewModel: viewModel)
        syncVOCAlert(for: sensor, viewModel: viewModel)
        syncNOXAlert(for: sensor, viewModel: viewModel)
        syncSoundAlert(for: sensor, viewModel: viewModel)
        syncLuminosityAlert(for: sensor, viewModel: viewModel)
        syncConnectionAlert(for: sensor, viewModel: viewModel)
        syncMovementAlert(for: sensor, viewModel: viewModel)
        syncCloudConnectionAlert(for: sensor, viewModel: viewModel)
        
        updateOverallAlertState(for: viewModel)
    }

    func getAlertBounds(for sensor: AnyRuuviTagSensor) -> (lower: Double?, upper: Double?) {
        let lower = alertService.lowerRelativeHumidity(for: sensor)
        let upper = alertService.upperRelativeHumidity(for: sensor)
        return (lower, upper)
    }

    // MARK: - Private Methods
    private func handleAlertChange(_ notification: Notification) {
        // Handle alert state changes from notification
        // This would be called when alerts are triggered or resolved
        guard let userInfo = notification.userInfo else { return }
        
        if let physicalSensor = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
           let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {
            
            let sensorId = physicalSensor.id
            if _alertState[sensorId] == nil {
                _alertState[sensorId] = [:]
            }
            
            // Update alert state based on whether alert is registered
            let isRegistered = alertService.hasRegistrations(for: physicalSensor)
            _alertState[sensorId]?[type] = isRegistered ? .registered : nil
            
            onAlertStateChanged?(_alertState)
        }
    }
    
    // MARK: - Individual Alert Sync Methods
    private func syncTemperatureAlert(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        if case .temperature = alertService.alert(for: sensor, of: .temperature(lower: 0, upper: 0)) {
            viewModel.isTemperatureAlertOn = true
            viewModel.temperatureAlertState = .registered
        } else {
            viewModel.isTemperatureAlertOn = false
            viewModel.temperatureAlertState = nil
        }
        viewModel.temperatureAlertMutedTill = alertService.mutedTill(type: .temperature(lower: 0, upper: 0), for: sensor)
    }
    
    private func syncHumidityAlert(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        if case .relativeHumidity = alertService.alert(for: sensor, of: .relativeHumidity(lower: 0, upper: 0)) {
            viewModel.isRelativeHumidityAlertOn = true
            viewModel.relativeHumidityAlertState = .registered
        } else {
            viewModel.isRelativeHumidityAlertOn = false
            viewModel.relativeHumidityAlertState = nil
        }
        viewModel.relativeHumidityAlertMutedTill = alertService.mutedTill(type: .relativeHumidity(lower: 0, upper: 0), for: sensor)
    }
    
    private func syncPressureAlert(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        if case .pressure = alertService.alert(for: sensor, of: .pressure(lower: 0, upper: 0)) {
            viewModel.isPressureAlertOn = true
            viewModel.pressureAlertState = .registered
        } else {
            viewModel.isPressureAlertOn = false
            viewModel.pressureAlertState = nil
        }
        viewModel.pressureAlertMutedTill = alertService.mutedTill(type: .pressure(lower: 0, upper: 0), for: sensor)
    }
    
    private func syncSignalAlert(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        if case .signal = alertService.alert(for: sensor, of: .signal(lower: 0, upper: 0)) {
            viewModel.isSignalAlertOn = true
            viewModel.signalAlertState = .registered
        } else {
            viewModel.isSignalAlertOn = false
            viewModel.signalAlertState = nil
        }
        viewModel.signalAlertMutedTill = alertService.mutedTill(type: .signal(lower: 0, upper: 0), for: sensor)
    }
    
    private func syncCarbonDioxideAlert(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        if case .carbonDioxide = alertService.alert(for: sensor, of: .carbonDioxide(lower: 0, upper: 0)) {
            viewModel.isCarbonDioxideAlertOn = true
            viewModel.carbonDioxideAlertState = .registered
        } else {
            viewModel.isCarbonDioxideAlertOn = false
            viewModel.carbonDioxideAlertState = nil
        }
        viewModel.carbonDioxideAlertMutedTill = alertService.mutedTill(type: .carbonDioxide(lower: 0, upper: 0), for: sensor)
    }
    
    private func syncParticulateMatterAlerts(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        // PM1
        if case .pMatter1 = alertService.alert(for: sensor, of: .pMatter1(lower: 0, upper: 0)) {
            viewModel.isPMatter1AlertOn = true
            viewModel.pMatter1AlertState = .registered
        } else {
            viewModel.isPMatter1AlertOn = false
            viewModel.pMatter1AlertState = nil
        }
        viewModel.pMatter1AlertMutedTill = alertService.mutedTill(type: .pMatter1(lower: 0, upper: 0), for: sensor)
        
        // PM2.5
        if case .pMatter2_5 = alertService.alert(for: sensor, of: .pMatter2_5(lower: 0, upper: 0)) {
            viewModel.isPMatter2_5AlertOn = true
            viewModel.pMatter2_5AlertState = .registered
        } else {
            viewModel.isPMatter2_5AlertOn = false
            viewModel.pMatter2_5AlertState = nil
        }
        viewModel.pMatter2_5AlertMutedTill = alertService.mutedTill(type: .pMatter2_5(lower: 0, upper: 0), for: sensor)
        
        // PM4
        if case .pMatter4 = alertService.alert(for: sensor, of: .pMatter4(lower: 0, upper: 0)) {
            viewModel.isPMatter4AlertOn = true
            viewModel.pMatter4AlertState = .registered
        } else {
            viewModel.isPMatter4AlertOn = false
            viewModel.pMatter4AlertState = nil
        }
        viewModel.pMatter4AlertMutedTill = alertService.mutedTill(type: .pMatter4(lower: 0, upper: 0), for: sensor)
        
        // PM10
        if case .pMatter10 = alertService.alert(for: sensor, of: .pMatter10(lower: 0, upper: 0)) {
            viewModel.isPMatter10AlertOn = true
            viewModel.pMatter10AlertState = .registered
        } else {
            viewModel.isPMatter10AlertOn = false
            viewModel.pMatter10AlertState = nil
        }
        viewModel.pMatter10AlertMutedTill = alertService.mutedTill(type: .pMatter10(lower: 0, upper: 0), for: sensor)
    }
    
    private func syncVOCAlert(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        if case .voc = alertService.alert(for: sensor, of: .voc(lower: 0, upper: 0)) {
            viewModel.isVOCAlertOn = true
            viewModel.vocAlertState = .registered
        } else {
            viewModel.isVOCAlertOn = false
            viewModel.vocAlertState = nil
        }
        viewModel.vocAlertMutedTill = alertService.mutedTill(type: .voc(lower: 0, upper: 0), for: sensor)
    }
    
    private func syncNOXAlert(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        if case .nox = alertService.alert(for: sensor, of: .nox(lower: 0, upper: 0)) {
            viewModel.isNOXAlertOn = true
            viewModel.noxAlertState = .registered
        } else {
            viewModel.isNOXAlertOn = false
            viewModel.noxAlertState = nil
        }
        viewModel.noxAlertMutedTill = alertService.mutedTill(type: .nox(lower: 0, upper: 0), for: sensor)
    }
    
    private func syncSoundAlert(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        if case .sound = alertService.alert(for: sensor, of: .sound(lower: 0, upper: 0)) {
            viewModel.isSoundAlertOn = true
            viewModel.soundAlertState = .registered
        } else {
            viewModel.isSoundAlertOn = false
            viewModel.soundAlertState = nil
        }
        viewModel.soundAlertMutedTill = alertService.mutedTill(type: .sound(lower: 0, upper: 0), for: sensor)
    }
    
    private func syncLuminosityAlert(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        if case .luminosity = alertService.alert(for: sensor, of: .luminosity(lower: 0, upper: 0)) {
            viewModel.isLuminosityAlertOn = true
            viewModel.luminosityAlertState = .registered
        } else {
            viewModel.isLuminosityAlertOn = false
            viewModel.luminosityAlertState = nil
        }
        viewModel.luminosityAlertMutedTill = alertService.mutedTill(type: .luminosity(lower: 0, upper: 0), for: sensor)
    }
    
    private func syncConnectionAlert(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        if case .connection = alertService.alert(for: sensor, of: .connection) {
            viewModel.isConnectionAlertOn = true
            viewModel.connectionAlertState = .registered
        } else {
            viewModel.isConnectionAlertOn = false
            viewModel.connectionAlertState = nil
        }
        viewModel.connectionAlertMutedTill = alertService.mutedTill(type: .connection, for: sensor)
    }
    
    private func syncMovementAlert(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        if case .movement = alertService.alert(for: sensor, of: .movement(last: 0)) {
            viewModel.isMovementAlertOn = true
            viewModel.movementAlertState = .registered
        } else {
            viewModel.isMovementAlertOn = false
            viewModel.movementAlertState = nil
        }
        viewModel.movementAlertMutedTill = alertService.mutedTill(type: .movement(last: 0), for: sensor)
    }
    
    private func syncCloudConnectionAlert(for sensor: AnyRuuviTagSensor, viewModel: CardsViewModel) {
        if case .cloudConnection = alertService.alert(for: sensor, of: .cloudConnection(unseenDuration: 0)) {
            viewModel.isCloudConnectionAlertOn = true
            viewModel.cloudConnectionAlertState = .registered
        } else {
            viewModel.isCloudConnectionAlertOn = false
            viewModel.cloudConnectionAlertState = nil
        }
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
}

// MARK: - RuuviNotifierObserver
extension AlertManagementService: RuuviNotifierObserver {
    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        // No op here.
    }
    
    func ruuvi(
        notifier: RuuviNotifier,
        alertType: AlertType,
        isTriggered: Bool,
        for uuid: String
    ) {
        if _alertState[uuid] == nil {
            _alertState[uuid] = [:]
        }
        
        let alertState: AlertState = isTriggered ? .firing : .registered
        _alertState[uuid]?[alertType] = alertState
        
        onAlertStateChanged?(_alertState)
    }
}
