import RuuviOntology
import Foundation

protocol CardsMeasurementViewOutput: AnyObject {
    func measurementViewDidLoad()
    func measurementViewDidBecomeActive()
    func measurementViewDidSelectMeasurement(_ type: MeasurementType)
    func measurementViewDidChangeSnapshotIndex(_ index: Int)
}
