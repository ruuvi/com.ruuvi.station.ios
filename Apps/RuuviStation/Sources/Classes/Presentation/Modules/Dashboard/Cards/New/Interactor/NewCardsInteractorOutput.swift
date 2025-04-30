import Foundation
import RuuviOntology

protocol NewCardsInteractorOutput: AnyObject {
    func createChartModules(
        from types: [MeasurementType],
        for sensor: RuuviTagSensor
    )
    func insertMeasurements(
        _ newValues: [RuuviMeasurement],
        for sensor: RuuviTagSensor
    )
    func updateLatestRecord(
        _ record: RuuviTagSensorRecord,
        for sensor: RuuviTagSensor
    )
    func interactorDidUpdate(
        sensor: RuuviTagSensor
    )
    func interactorDidError(
        _ error: RUError,
        for sensor: RuuviTagSensor
    )
}
