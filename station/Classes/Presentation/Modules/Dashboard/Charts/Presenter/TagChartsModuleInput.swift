import Foundation
import RuuviOntology

protocol TagChartsModuleInput: AnyObject {
    func configure(output: TagChartsModuleOutput)
    func configure(ruuviTag: AnyRuuviTagSensor)
    func dismiss(completion: (() -> Void)?)
}
extension TagChartsModuleInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
