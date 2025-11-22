import Foundation
import RuuviOntology

protocol MeasurementDetailsPresenterOutput: AnyObject {
    func detailsViewDidDismiss(
        for snapshot: RuuviTagCardSnapshot,
        measurement: MeasurementType,
        variant: MeasurementDisplayVariant?,
        ruuviTag: RuuviTagSensor,
        module: MeasurementDetailsPresenterInput
    )
}
