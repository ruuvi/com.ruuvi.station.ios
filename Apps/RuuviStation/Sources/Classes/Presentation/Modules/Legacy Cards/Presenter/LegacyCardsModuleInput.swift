import Foundation
import RuuviOntology

protocol LegacyCardsModuleInput: AnyObject {
    func configure(
        viewModels: [LegacyCardsViewModel],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings]
    )
    func configure(
        scrollTo: LegacyCardsViewModel?,
        openChart: Bool
    )
    func configure(output: LegacyCardsModuleOutput)
    func dismiss(completion: (() -> Void)?)
}

extension LegacyCardsModuleInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
