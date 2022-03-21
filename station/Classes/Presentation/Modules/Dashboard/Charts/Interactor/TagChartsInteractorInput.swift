import Foundation
import Future
import BTKit
import RuuviOntology

protocol TagChartsInteractorInput: AnyObject {
    var chartViews: [TagChartView] { get }
    var lastMeasurement: RuuviMeasurement? { get }
    func configure(withTag ruuviTag: AnyRuuviTagSensor,
                   andSettings settings: SensorSettings?)
    func updateSensorSettings(settings: SensorSettings?)
    func restartObservingTags()
    func stopObservingTags()
    func restartObservingData()
    func stopObservingRuuviTagsData()
    func export() -> Future<URL, RUError>
    func syncRecords(progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError>
    func isSyncingRecords() -> Bool
    func deleteAllRecords(for sensor: RuuviTagSensor) -> Future<Void, RUError>
    func notifySettingsChanged()
    func notifyDownsamleOnDidChange()
    func notifyDidLocalized()
}
