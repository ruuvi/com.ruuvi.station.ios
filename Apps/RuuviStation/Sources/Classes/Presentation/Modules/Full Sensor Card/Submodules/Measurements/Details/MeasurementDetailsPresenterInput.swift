import Foundation
import RuuviOntology

protocol MeasurementDetailsPresenterInput: AnyObject {
    func configure(
        with snapshot: RuuviTagCardSnapshot,
        measurementType: MeasurementType,
        variant: MeasurementDisplayVariant?,
        ruuviTag: RuuviTagSensor,
        sensorSettings: SensorSettings?,
        output: MeasurementDetailsPresenterOutput
    )
    func start()
    func stop()
}
