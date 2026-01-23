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
    func export() async throws -> URL
    func syncRecords(progress: ((BTServiceProgress) -> Void)?) async throws -> Void
    func stopSyncRecords() async throws -> Bool
    func isSyncingRecords() -> Bool
    func deleteAllRecords(for sensor: RuuviTagSensor) async throws -> Void
    func updateChartShowMinMaxAvgSetting(with show: Bool)
}
