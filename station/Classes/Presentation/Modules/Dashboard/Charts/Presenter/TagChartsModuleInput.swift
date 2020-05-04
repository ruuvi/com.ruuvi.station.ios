import Foundation

protocol TagChartsModuleInput: class {
    func configure(output: TagChartsModuleOutput)
    func configure(ruuviTag: AnyRuuviTagSensor)
    func dismiss()
}
