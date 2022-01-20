import Foundation
import RuuviOntology

protocol TagChartModuleInput: AnyObject {
    var chartView: TagChartView { get }
    func configure(_ viewModel: TagChartViewModel, sensorSettings: SensorSettings, output: TagChartModuleOutput, luid: LocalIdentifier?)
    func insertMeasurements(_ newValues: [RuuviMeasurement])
    func removeMeasurements(_ oldValues: [RuuviMeasurement])
    func setProgress(_ value: Float)
    func reloadChart()
    func localize()
    func notifySettingsChanged()
}
