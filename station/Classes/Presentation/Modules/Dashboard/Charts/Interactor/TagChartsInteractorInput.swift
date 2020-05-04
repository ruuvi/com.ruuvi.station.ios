import Foundation
import Future
import BTKit

protocol TagChartsInteractorInput: class {
    func configure(withTag ruuviTag: AnyRuuviTagSensor)
    func restartObservingData()
    func stopObservingRuuviTagsData()
    func export() -> Future<URL, RUError>
    func syncRecords(progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError>
    func deleteAllRecords() -> Future<Void, RUError>
}
