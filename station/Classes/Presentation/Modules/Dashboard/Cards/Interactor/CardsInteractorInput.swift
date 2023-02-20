import Foundation
import Future
import RuuviOntology
import RuuviLocal

protocol CardsInteractorInput: AnyObject {
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor,
                                       settings: RuuviLocalSettings)
    func migrateFWVersionFromDefaults(for ruuviTags: [RuuviTagSensor],
                                      settings: RuuviLocalSettings)
}
