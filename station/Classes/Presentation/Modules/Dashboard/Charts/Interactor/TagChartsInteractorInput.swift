import Foundation
import Future
import BTKit

protocol TagChartsInteractorInput: class {
    var chartViews: [TagChartView] { get }
    func configure(withTag ruuviTag: AnyRuuviTagSensor)
    func startObservingTags()
    func stopObservingTags()
    func restartObservingData()
    func stopObservingRuuviTagsData()
    func export() -> Future<URL, RUError>
    func syncRecords(progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError>
    func deleteAllRecords() -> Future<Void, RUError>
    func notifySettingsChanged()
}
