import BTKit
import Foundation
import RuuviOntology

protocol TagChartsViewInteractorInput: AnyObject {
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
    func export() async throws -> URL
    func syncRecords(progress: ((BTServiceProgress) -> Void)?) async throws
    func stopSyncRecords() async throws -> Bool
    func isSyncingRecords() -> Bool
    func deleteAllRecords(for sensor: RuuviTagSensor) async throws
    func updateChartShowMinMaxAvgSetting(with show: Bool)
}
