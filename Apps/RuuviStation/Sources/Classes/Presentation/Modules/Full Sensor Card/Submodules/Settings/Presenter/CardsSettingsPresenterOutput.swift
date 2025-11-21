import Foundation
import RuuviOntology

protocol CardsSettingsPresenterOutput: AnyObject {
    func cardSettingsDidDeleteDevice(
        module: CardsSettingsPresenterInput,
        ruuviTag: RuuviTagSensor
    )
    func cardSettingsDidDismiss(module: CardsSettingsPresenterInput)
}
