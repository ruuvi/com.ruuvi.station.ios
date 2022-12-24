import Foundation
import Future
import RuuviOntology
import RuuviLocal

protocol CardsInteractorInput: AnyObject {
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor)
    func migrateFWVersionFromDefaults(for ruuviTags: [RuuviTagSensor],
                                      settings: RuuviLocalSettings)
}
