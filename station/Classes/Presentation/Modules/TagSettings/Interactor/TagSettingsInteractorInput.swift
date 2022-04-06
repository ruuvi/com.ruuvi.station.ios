import Foundation
import Future
import RuuviOntology

protocol TagSettingsInteractorInput: AnyObject {
    func checkFirmwareVersion(for luid: String) -> Future<String, RUError>
}
