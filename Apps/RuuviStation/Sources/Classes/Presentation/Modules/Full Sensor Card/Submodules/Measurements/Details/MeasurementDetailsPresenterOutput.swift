import Foundation
import RuuviOntology

protocol MeasurementDetailsPresenterOutput: AnyObject {
    func detailsViewDidDismiss(
        for snapshot: RuuviTagCardSnapshot,
        measurement: MeasurementType,
        ruuviTag: RuuviTagSensor,
        module: MeasurementDetailsPresenterInput
    )
}
