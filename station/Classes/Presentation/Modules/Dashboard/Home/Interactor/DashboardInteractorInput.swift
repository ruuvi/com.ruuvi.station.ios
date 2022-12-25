import Foundation
import Future
import RuuviOntology
import RuuviLocal

protocol DashboardInteractorInput: AnyObject {
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor)
    func migrateFWVersionFromDefaults(for ruuviTags: [RuuviTagSensor])
}
