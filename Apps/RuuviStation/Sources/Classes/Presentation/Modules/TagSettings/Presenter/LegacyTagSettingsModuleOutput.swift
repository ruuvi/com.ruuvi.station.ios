import Foundation
import RuuviOntology

protocol LegacyTagSettingsModuleOutput: AnyObject {
    func tagSettingsDidDeleteTag(
        module: LegacyTagSettingsModuleInput,
        ruuviTag: RuuviTagSensor
    )
    func tagSettingsDidDismiss(module: LegacyTagSettingsModuleInput)
}
