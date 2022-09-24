import Foundation
import RuuviOntology

protocol TagChartsViewModuleInput: AnyObject {
    func configure(output: TagChartsViewModuleOutput)
    func configure(ruuviTag: AnyRuuviTagSensor)
    func dismiss(completion: (() -> Void)?)
}
extension TagChartsViewModuleInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
