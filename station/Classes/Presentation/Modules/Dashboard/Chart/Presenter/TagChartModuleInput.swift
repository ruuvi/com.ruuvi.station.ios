import Foundation

protocol TagChartModuleInput: class {
    func configure(type: MeasurementType, output: TagChartModuleOutput)
}
