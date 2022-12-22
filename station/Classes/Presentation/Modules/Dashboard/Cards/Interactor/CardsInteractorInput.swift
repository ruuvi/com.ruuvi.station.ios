import Foundation
import Future
import RuuviOntology

protocol CardsInteractorInput: AnyObject {
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor)
}
