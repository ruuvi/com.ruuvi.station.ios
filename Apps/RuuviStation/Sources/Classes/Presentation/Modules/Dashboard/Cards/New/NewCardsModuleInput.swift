import Foundation
import RuuviOntology

protocol NewCardsModuleInput: AnyObject {
    func configure(
        viewModels: [CardsViewModel],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        scrollTo: CardsViewModel?,
        openWith: SensorCardSelectedTab,
        output: CardsModuleOutput
    )
    func dismiss(completion: (() -> Void)?)
}

extension NewCardsModuleInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
