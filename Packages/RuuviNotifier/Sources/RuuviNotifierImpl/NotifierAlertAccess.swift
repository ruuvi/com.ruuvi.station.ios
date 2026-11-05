import RuuviOntology
import RuuviService

/// The notifier only reads alert state and advances the movement baseline.
protocol NotifierAlertAccess {
    func hasRegistrations(for sensor: PhysicalSensor) -> Bool
    func alert(for uuid: String, of type: AlertType) -> AlertType?
    func isOn(type: AlertType, for uuid: String) -> Bool
    func isOn(type: AlertType, for sensor: PhysicalSensor) -> Bool
    func setMovement(counter: Int?, for sensor: PhysicalSensor)
}

struct ServiceNotifierAlerts: NotifierAlertAccess {
    let service: RuuviServiceAlert
    func hasRegistrations(for sensor: PhysicalSensor) -> Bool { service.hasRegistrations(for: sensor) }
    func alert(for uuid: String, of type: AlertType) -> AlertType? { service.alert(for: uuid, of: type) }
    func isOn(type: AlertType, for uuid: String) -> Bool { service.isOn(type: type, for: uuid) }
    func isOn(type: AlertType, for sensor: PhysicalSensor) -> Bool { service.isOn(type: type, for: sensor) }
    func setMovement(counter: Int?, for sensor: PhysicalSensor) { service.setMovement(counter: counter, for: sensor) }
}
