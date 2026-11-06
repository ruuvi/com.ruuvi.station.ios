import Foundation
import RuuviOntology
@testable import station

final class CardChildPresenterSpy: CardsMeasurementPresenterInput, CardsGraphPresenterInput,
    CardsAlertsPresenterInput, CardsSettingsPresenterInput
{
    struct Configuration {
        let ids: [String]
        let selected: String
        let sensor: String?
        let settings: SensorSettings?
    }
    var configurations = [Configuration]()
    var starts = 0
    var syncStarts = [Bool]()
    var stops = 0
    var dismissals = 0
    var scrolls = [(Int, Bool)]()
    var metrics = [(MeasurementType, MeasurementDisplayVariant?)]()
    var aborts = [GraphHistoryAbortSyncSource]()
    var reloads = [Bool]()
    weak var measurementOutput: CardsMeasurementPresenterOutput?
    weak var graphOutput: CardsGraphPresenterOutput?
    func configure(
        with snapshots: [RuuviTagCardSnapshot], snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor?, settings: SensorSettings?
    ) {
        configurations.append(
            .init(ids: snapshots.map(\.id), selected: snapshot.id, sensor: sensor?.id, settings: settings))
    }
    func configure(with snapshot: RuuviTagCardSnapshot, sensor: AnyRuuviTagSensor?, settings: SensorSettings?) {
        configurations.append(.init(ids: [], selected: snapshot.id, sensor: sensor?.id, settings: settings))
    }
    func configure(output: CardsMeasurementPresenterOutput?) { measurementOutput = output }
    func configure(output: CardsGraphPresenterOutput?) { graphOutput = output }
    func start() { starts += 1 }
    func start(shouldSyncFromCloud: Bool) { syncStarts.append(shouldSyncFromCloud) }
    func stop() { stops += 1 }
    func scroll(to index: Int, animated: Bool) { scrolls.append((index, animated)) }
    func scroll(to measurementType: MeasurementType, variant: MeasurementDisplayVariant?) {
        metrics.append((measurementType, variant))
    }
    func showAbortSyncConfirmationDialog(for snapshot: RuuviTagCardSnapshot, from source: GraphHistoryAbortSyncSource) {
        aborts.append(source)
    }
    func reloadChartsData(shouldSyncFromCloud: Bool) { reloads.append(shouldSyncFromCloud) }
    func dismiss(completion: (() -> Void)?) { dismissals += 1; completion?() }
}

final class CardsBaseViewSpy: CardsBaseViewInput {
    var active = [CardsMenuType]()
    var shown = [CardsMenuType]()
    var lists = [[String]]()
    var updates = [String]()
    var indexes = [Int]()
    var activity = [Bool]()
    var bluetooth = [Bool]()
    var chartPrompts = [String]()
    var settingsPrompts = [String]()
    var firmwarePrompts = [String]()
    var firmwareConfirmations = [String]()
    var details = [String]()
    func setActiveTab(_ tab: CardsMenuType) { active.append(tab) }
    func showContentsForTab(_ tab: CardsMenuType) { shown.append(tab) }
    func setSnapshots(_ snapshots: [RuuviTagCardSnapshot]) { lists.append(snapshots.map(\.id)) }
    func updateSnapshot(_ snapshot: RuuviTagCardSnapshot) { updates.append(snapshot.id) }
    func setActiveSnapshotIndex(_ index: Int) { indexes.append(index) }
    func setActivityIndicatorVisible(_ visible: Bool) { activity.append(visible) }
    func showBluetoothDisabled(userDeclined: Bool) { bluetooth.append(userDeclined) }
    func showKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot) { chartPrompts.append(snapshot.id) }
    func showKeepConnectionDialogSettings(for snapshot: RuuviTagCardSnapshot) { settingsPrompts.append(snapshot.id) }
    func showFirmwareUpdateDialog(for snapshot: RuuviTagCardSnapshot) { firmwarePrompts.append(snapshot.id) }
    func showFirmwareDismissConfirmationUpdateDialog(for snapshot: RuuviTagCardSnapshot) {
        firmwareConfirmations.append(snapshot.id)
    }
    func showMeasurementDetails(
        for indicator: RuuviTagCardSnapshotIndicatorData, snapshot: RuuviTagCardSnapshot,
        sensor: RuuviTagSensor, settings: SensorSettings?
    ) { details.append(snapshot.id) }
}

final class CardsBaseOutputSpy: CardsBasePresenterOutput, CardsRouterInput {
    var dismissals = 0
    var firmware = [String]()
    func cardsViewDidDismiss(module: CardsBasePresenterInput) { dismissals += 1 }
    func openUpdateFirmware(ruuviTag: RuuviTagSensor) { firmware.append(ruuviTag.id) }
    func dismiss() { dismissals += 1 }
}
