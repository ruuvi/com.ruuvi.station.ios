import Foundation
import RuuviOntology

protocol NewCardsModuleInput: AnyObject {
    func configure(
        activeSnapshot: RuuviTagCardSnapshot,
        snapshots: [RuuviTagCardSnapshot],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        activeMenu: CardsMenuType,
        output: NewCardsModuleOutput
    )

    func dismiss(completion: (() -> Void)?)
}

extension NewCardsModuleInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
