import BTKit
import Foundation
import RuuviOntology
import RuuviService
@testable import station

@MainActor final class GraphHistoryFixture {
    let measurements = MeasurementFixture()
    let reactor = AppTestReactor()
    let pool = AppPoolSpy()
    let sync = AppSyncStateSpy()
    let gatt = AdvertisementGattSpy()
    let records = GraphHistoryRecordsSpy()
    let export = GraphExportSpy()
    let output = GraphHistoryOutputSpy()
    let interactor = CardsGraphViewInteractor()
    let appSettings: AppSettingsServiceSpy
    init() {
        appSettings = AppSettingsServiceSpy(settings: measurements.settings)
        measurements.storage.useLatestOverride = true
        interactor.presenter = output
        interactor.gattService = gatt
        interactor.ruuviPool = pool
        interactor.ruuviStorage = measurements.storage
        interactor.ruuviReactor = reactor
        interactor.cloudSyncService = measurements.cloud
        interactor.settings = measurements.settings
        interactor.flags = measurements.flags
        interactor.ruuviTagSensor = measurements.sensor.any
        interactor.exportService = export
        interactor.ruuviSensorRecords = records
        interactor.featureToggleService = FeatureToggleService()
        interactor.localSyncState = sync
        interactor.ruuviAppSettingsService = appSettings
    }
    func cleanup() { interactor.stopObservingTags(); interactor.stopObservingRuuviTagsData(); measurements.cleanup() }
}

@MainActor final class GraphHistoryRecordsSpy: RuuviServiceSensorRecords {
    var cleared = [String]()
    var failure: RuuviServiceError?
    var beforeClear: (() -> Void)?
    func clear(for sensor: RuuviTagSensor) async throws(RuuviServiceError) {
        beforeClear?()
        cleared.append(sensor.id)
        if let failure { throw failure }
    }
}

final class GraphHistoryOutputSpy: CardsGraphViewInteractorOutput {
    var inserts = [[RuuviMeasurement]]()
    var latest = [RuuviTagSensorRecord]()
    var errors = [RUError]()
    var variants = [[MeasurementDisplayVariant]]()
    var sensors = [AnyRuuviTagSensor]()
    var loaded = 0
    func insertMeasurements(_ newValues: [RuuviMeasurement]) { inserts.append(newValues) }
    func updateLatestRecord(_ record: RuuviTagSensorRecord) { latest.append(record) }
    func interactorDidError(_ error: RUError) { errors.append(error) }
    func createChartModules(from variants: [MeasurementDisplayVariant]) { self.variants.append(variants) }
    func interactorDidUpdate(sensor: AnyRuuviTagSensor) { sensors.append(sensor) }
    func interactorDidFinishLoadingHistory() { loaded += 1 }
}
