import BTKit
import Foundation
import Future
import RuuviOntology

protocol TagChartsViewInteractorInput: AnyObject {
    var ruuviTagData: [RuuviMeasurement] { get }
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
    func stopSyncRecords() -> Future<Bool, RUError>
    func isSyncingRecords() -> Bool
    func deleteAllRecords(for sensor: RuuviTagSensor) -> Future<Void, RUError>
    func updateChartShowMinMaxAvgSetting(with show: Bool)
}
