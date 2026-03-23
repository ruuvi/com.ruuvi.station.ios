import Foundation
import RuuviOntology

protocol CardsSettingsPresenterOutput: AnyObject {
    func cardSettingsDidDeleteDevice(
        module: CardsSettingsPresenterInput,
        ruuviTag: RuuviTagSensor
    )
    func cardSettingsDidRequestOpenAlerts(module: CardsSettingsPresenterInput)
    func cardSettingsDidDismiss(module: CardsSettingsPresenterInput)
}
