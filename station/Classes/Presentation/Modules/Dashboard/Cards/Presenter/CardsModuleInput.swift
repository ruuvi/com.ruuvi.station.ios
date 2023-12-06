import Foundation
import RuuviOntology

protocol CardsModuleInput: AnyObject {
    func configure(viewModels: [CardsViewModel],
                   ruuviTagSensors: [AnyRuuviTagSensor],
                   sensorSettings: [SensorSettings])
    func configure(scrollTo: CardsViewModel?,
                   openChart: Bool)
    func configure(output: CardsModuleOutput)
    func dismiss(completion: (() -> Void)?)
}

extension CardsModuleInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
