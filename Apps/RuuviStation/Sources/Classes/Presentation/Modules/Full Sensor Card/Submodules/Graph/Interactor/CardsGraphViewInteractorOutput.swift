import Foundation
import RuuviOntology

protocol CardsGraphViewInteractorOutput: AnyObject {
    func insertMeasurements(_ newValues: [RuuviMeasurement])
    func updateLatestRecord(_ record: RuuviTagSensorRecord)
    func interactorDidError(_ error: RUError)
    func createChartModules(from: [MeasurementType])
    func interactorDidUpdate(sensor: AnyRuuviTagSensor)
}
