import Foundation
import Future
import RuuviLocal
import RuuviOntology

protocol DashboardInteractorInput: AnyObject {
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor)
}
