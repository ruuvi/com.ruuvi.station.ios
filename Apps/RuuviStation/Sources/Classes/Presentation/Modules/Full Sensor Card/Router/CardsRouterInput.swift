import Foundation
import RuuviOntology

protocol CardsRouterInput {
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    func dismiss()
}
