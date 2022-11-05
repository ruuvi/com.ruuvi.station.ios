import Foundation
import RuuviOntology

protocol TagChartsViewInteractorOutput: AnyObject {
    var isLoading: Bool { get set }
    func insertMeasurements(_ newValues: [RuuviMeasurement])
    func interactorDidError(_ error: RUError)
    func createChartModules(from: [MeasurementType])
    func interactorDidUpdate(sensor: AnyRuuviTagSensor)
    func interactorDidSyncComplete(_ recordsCount: Int)
}
