import BTKit
import Foundation
import RuuviOntology
@testable import station

final class GraphInteractorSpy: CardsGraphViewInteractorInput {
    var ruuviTagData = [RuuviMeasurement]()
    var lastMeasurement: RuuviMeasurement? { ruuviTagData.last }
    var configurations = [(AnyRuuviTagSensor, SensorSettings?, Bool)]()
    var calibrations = [SensorSettings?]()
    var tagStarts = 0
    var tagStops = 0
    var dataStarts = 0
    var dataStops = 0
    var syncs = 0
    var stops = 0
    var deleted = [String]()
    var statistics = [Bool]()
    var syncing = false
    var syncingAny = false
    var queued = false
    var suppressed = false
    var progress: BTServiceProgress?
    var lastSync: Date?
    var attempt: Date?
    var logged = false
    var failure: RUError?
    var beforeSync: (() async -> Void)?
    var onProgress: ((BTServiceProgress) -> Void)?
    func configure(withTag ruuviTag: AnyRuuviTagSensor, andSettings settings: SensorSettings?, syncFromCloud: Bool) {
        configurations.append((ruuviTag, settings, syncFromCloud))
    }
    func updateSensorSettings(settings: SensorSettings?) { calibrations.append(settings) }
    func restartObservingTags() { tagStarts += 1 }
    func stopObservingTags() { tagStops += 1 }
    func restartObservingData() { dataStarts += 1 }
    func stopObservingRuuviTagsData() { dataStops += 1 }
    @MainActor func export() async throws(RUError) -> URL { throw .unexpected(.failedToFindLogsForTheTag) }
    @MainActor func syncRecords(progress: ((BTServiceProgress) -> Void)?) async throws(RUError) {
        syncs += 1
        onProgress = progress
        await beforeSync?()
        if let failure { throw failure }
    }
    @MainActor func stopSyncRecords() async throws(RUError) -> Bool {
        stops += 1
        if let failure { throw failure }
        return true
    }
    func isSyncingAnyRecords() -> Bool { syncingAny }
    func isSyncingRecords(for luid: LocalIdentifier?) -> Bool { syncing }
    func isSyncingRecordsQueued(for luid: LocalIdentifier?) -> Bool { queued }
    func currentSyncProgress(for luid: LocalIdentifier?) -> BTServiceProgress? { progress }
    func isAutoGattSyncSuppressed() -> Bool { suppressed }
    func getLastGattSyncDate() -> Date? { lastSync }
    func getAutoGattSyncAttemptDate() -> Date? { attempt }
    func setAutoGattSyncAttemptDate(_ date: Date?) { attempt = date }
    func hasLoggedFirstAutoSyncGattHistoryForRuuviAir() -> Bool { logged }
    func setHasLoggedFirstAutoSyncGattHistoryForRuuviAir(_ logged: Bool) { self.logged = logged }
    @MainActor func deleteAllRecords(for sensor: RuuviTagSensor) async throws(RUError) {
        deleted.append(sensor.id)
        if let failure { throw failure }
    }
    func updateChartShowMinMaxAvgSetting(with show: Bool) { statistics.append(show) }
}
