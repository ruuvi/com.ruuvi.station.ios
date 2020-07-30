import Foundation

protocol TagChartsModuleInput: class {
    func configure(output: TagChartsModuleOutput)
    func configure(ruuviTag: AnyRuuviTagSensor)
    func dismiss(completion: (() -> Void)?)
}
extension TagChartsModuleInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
