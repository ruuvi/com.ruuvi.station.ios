import Foundation
import RuuviLocal
import RuuviOntology

protocol DashboardInteractorInput: AnyObject {
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor)
}
