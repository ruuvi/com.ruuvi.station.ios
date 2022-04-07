import Foundation
import RuuviOntology

protocol OwnerRouterInput {
    func openUpdateFirmware(ruuviTag: RuuviTagSensor)
    func dismiss()
}
