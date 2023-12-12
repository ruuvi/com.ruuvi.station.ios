import Foundation
import RuuviOntology

protocol TagSettingsModuleOutput: AnyObject {
    func tagSettingsDidDeleteTag(
        module: TagSettingsModuleInput,
        ruuviTag: RuuviTagSensor
    )
    func tagSettingsDidDismiss(module: TagSettingsModuleInput)
}
