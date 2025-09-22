import Foundation
import RuuviLocal
import RuuviOntology

protocol CardsInteractorInput: AnyObject {
    func checkAndUpdateFirmwareVersion(
        for ruuviTag: RuuviTagSensor,
        settings: RuuviLocalSettings
    )
}
