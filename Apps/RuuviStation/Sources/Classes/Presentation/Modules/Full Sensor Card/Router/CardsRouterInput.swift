import Foundation
import RuuviOntology

protocol CardsRouterInput {
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    func openTagSettings(
        snapshot: RuuviTagCardSnapshot,
        ruuviTag: RuuviTagSensor,
        sensorSettings: SensorSettings?
    )
    func dismiss()
}
