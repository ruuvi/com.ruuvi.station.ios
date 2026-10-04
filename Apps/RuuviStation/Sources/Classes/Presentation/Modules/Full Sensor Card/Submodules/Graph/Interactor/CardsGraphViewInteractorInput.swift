import BTKit
import Foundation
import Future
import RuuviOntology
import RuuviStorage

protocol CardsGraphViewInteractorInput: AnyObject {
    func historyRevision() -> Future<Int, RuuviStorageError>
    func scanHistory(range: RuuviHistoryRange, cancellation: RuuviHistoryCancellation,
                     consume: @escaping (RuuviTagSensorRecord) -> Void) -> Future<Int, RuuviStorageError>
    func changeHistorySelection()
    var lastMeasurement: RuuviMeasurement? { get }
    func configure(
        withTag ruuviTag: AnyRuuviTagSensor,
        andSettings settings: SensorSettings?,
        syncFromCloud: Bool
    )
    func updateSensorSettings(settings: SensorSettings?)
    func restartObservingTags()
    func stopObservingTags()
    func restartObservingData()
    func stopObservingRuuviTagsData()
    func export() -> Future<URL, RUError>
    func syncRecords(progress: ((BTServiceProgress) -> Void)?) -> Future<Void, RUError>
    func stopSyncRecords() -> Future<Bool, RUError>
    func isSyncingRecords() -> Bool
    func isSyncingRecordsQueued() -> Bool
    func getLastGattSyncDate() -> Date?
    func getAutoGattSyncAttemptDate() -> Date?
    func setAutoGattSyncAttemptDate(_ date: Date?)
    func hasLoggedFirstAutoSyncGattHistoryForRuuviAir() -> Bool
    func setHasLoggedFirstAutoSyncGattHistoryForRuuviAir(_ logged: Bool)
    func deleteAllRecords(for sensor: RuuviTagSensor) -> Future<Void, RUError>
    func updateChartShowMinMaxAvgSetting(with show: Bool)
}
