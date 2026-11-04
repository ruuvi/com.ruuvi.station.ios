import BTKit
import Foundation
import RuuviOntology

protocol CardsGraphViewInteractorInput: AnyObject {
    var ruuviTagData: [RuuviMeasurement] { get }
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
    @MainActor func export() async throws(RUError) -> URL
    @MainActor func syncRecords(progress: ((BTServiceProgress) -> Void)?) async throws(RUError) -> Void
    @MainActor func stopSyncRecords() async throws(RUError) -> Bool
    func isSyncingAnyRecords() -> Bool
    func isSyncingRecords(for luid: LocalIdentifier?) -> Bool
    func isSyncingRecordsQueued(for luid: LocalIdentifier?) -> Bool
    func currentSyncProgress(for luid: LocalIdentifier?) -> BTServiceProgress?
    func isAutoGattSyncSuppressed() -> Bool
    func getLastGattSyncDate() -> Date?
    func getAutoGattSyncAttemptDate() -> Date?
    func setAutoGattSyncAttemptDate(_ date: Date?)
    func hasLoggedFirstAutoSyncGattHistoryForRuuviAir() -> Bool
    func setHasLoggedFirstAutoSyncGattHistoryForRuuviAir(_ logged: Bool)
    @MainActor func deleteAllRecords(for sensor: RuuviTagSensor) async throws(RUError) -> Void
    func updateChartShowMinMaxAvgSetting(with show: Bool)
}
