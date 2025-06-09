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
        // Temperature alerts
        if alertService.isOn(
            type: .temperature(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.temperatureAlertState = .registered
        }
        
        // Humidity alerts
        if alertService.isOn(
            type: .relativeHumidity(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.relativeHumidityAlertState = .registered
        }
        
        // Pressure alerts
        if alertService.isOn(
            type: .pressure(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.pressureAlertState = .registered
        }
        
        // Signal alerts
        if alertService.isOn(
            type: .signal(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.signalAlertState = .registered
        }
        
        // Carbon dioxide alerts
        if alertService.isOn(
            type: .carbonDioxide(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.carbonDioxideAlertState = .registered
        }
        
        // Particulate matter alerts
        if alertService.isOn(
            type: .pMatter1(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.pMatter1AlertState = .registered
        }
        
        if alertService.isOn(
            type: .pMatter2_5(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.pMatter2_5AlertState = .registered
        }
        
        if alertService.isOn(
            type: .pMatter4(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.pMatter4AlertState = .registered
        }
        
        if alertService.isOn(
            type: .pMatter10(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.pMatter10AlertState = .registered
        }
        
        // VOC alerts
        if alertService.isOn(
            type: .voc(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.vocAlertState = .registered
        }
        
        // NOx alerts
        if alertService.isOn(
            type: .nox(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.noxAlertState = .registered
        }
        
        // Sound alerts
        if alertService.isOn(
            type: .sound(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.soundAlertState = .registered
        }
        
        // Luminosity alerts
        if alertService.isOn(
            type: .luminosity(lower: 0, upper: 0), for: sensor
        ) {
            viewModel.luminosityAlertState = .registered
        }
        
        // Connection alerts
        if alertService.isOn(
            type: .connection, for: sensor
        ) {
            viewModel.connectionAlertState = .registered
        }
        
        // Movement alerts
        if alertService.isOn(
            type: .movement(last: 0), for: sensor
        ) {
            viewModel.movementAlertState = .registered
        }
        
        // Cloud connection alerts
        if alertService.isOn(
            type: .cloudConnection(unseenDuration: 0), for: sensor
        ) {
            viewModel.cloudConnectionAlertState = .registered
        }
        
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
