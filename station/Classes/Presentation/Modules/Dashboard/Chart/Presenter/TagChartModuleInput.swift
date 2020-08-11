import Foundation

protocol TagChartModuleInput: class {
    var chartView: TagChartView { get }
    func configure(_ viewModel: TagChartViewModel, output: TagChartModuleOutput, luid: LocalIdentifier?)
    func insertMeasurements(_ newValues: [RuuviMeasurement])
    func setProgress(_ value: Float)
    func reloadChart()
    func notifySettingsChanged()
}
