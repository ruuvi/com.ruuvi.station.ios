import BTKit
import DGCharts
import Foundation
import RuuviLocal
import RuuviOntology
@testable import station

final class GraphViewSpy: CardsGraphViewInput {
    var historyLengthInHours = 0
    var showChartStat = false
    var chartsPerScreen = 0
    var showChartAll = false
    var showAlertRangeInGraph = false
    var viewIsVisible = true
    var graphIsVisibleForUser = true
    var resets = 0
    var disabledBluetooth = [Bool]()
    var active: RuuviTagCardSnapshot?
    var modules = [[MeasurementDisplayVariant]]()
    var scrolls = [MeasurementDisplayVariant]()
    var cleared = 0
    var charts = [[RuuviGraphViewDataModel]]()
    var appended = [[MeasurementDisplayVariant: [ChartDataEntry]]]()
    var firstEntries = [Bool]()
    var latest = [[MeasurementDisplayVariant: ChartDataEntry?]]()
    var alertStates = [[MeasurementDisplayVariant: Bool]]()
    var hasData = [Bool]()
    var loading = [Bool]()
    var clearDialogs = [String]()
    var syncStates = [(String, String)]()
    var progressHidden = 0
    var inProgressDialogs = 0
    var syncFailures = 0
    var swipeHints = 0
    var syncConfirmations = [String]()
    var aborts = [GraphHistoryAbortSyncSource]()
    var swipeAborts = [Int]()
    var exports = [URL]()
    var longerHistory = 0
    var tutorials = 0
    func resetScrollPosition() { resets += 1 }
    func showBluetoothDisabled(userDeclined: Bool) { disabledBluetooth.append(userDeclined) }
    func setActiveSnapshot(_ snapshot: RuuviTagCardSnapshot?) { active = snapshot }
    func createChartViews(from: [MeasurementDisplayVariant]) { modules.append(from) }
    func scroll(to variant: MeasurementDisplayVariant) { scrolls.append(variant) }
    func clearChartHistory() { cleared += 1 }
    func setChartViewData(from chartViewData: [RuuviGraphViewDataModel], settings: RuuviLocalSettings) {
        charts.append(chartViewData)
    }
    func updateChartViewData(
        _ entries: [MeasurementDisplayVariant: [ChartDataEntry]], isFirstEntry: Bool,
        firstEntry: RuuviMeasurement?, settings: RuuviLocalSettings
    ) { appended.append(entries); firstEntries.append(isFirstEntry) }
    func updateLatestMeasurement(
        _ entries: [MeasurementDisplayVariant: ChartDataEntry?],
        alertStates: [MeasurementDisplayVariant: Bool], settings: RuuviLocalSettings
    ) { latest.append(entries); self.alertStates.append(alertStates) }
    func updateLatestAlertStates(_ alertStates: [MeasurementDisplayVariant: Bool]) {
        self.alertStates.append(alertStates)
    }
    func setHasChartData(_ hasData: Bool) { self.hasData.append(hasData) }
    func setChartLoading(hideCharts: Bool) { loading.append(hideCharts) }
    func showClearConfirmationDialog(for snapshot: RuuviTagCardSnapshot) { clearDialogs.append(snapshot.id) }
    func setSync(status: GraphGattSyncStatus?, for snapshot: RuuviTagCardSnapshot) {
        let text: String
        switch status {
        case .none: text = "idle"
        case .queued: text = "queued"
        case .progress(.connecting): text = "connecting"
        case .progress(.reading(let count)): text = "reading:\(count)"
        case .progress: text = "progress"
        }
        syncStates.append((snapshot.id, text))
    }
    func setSyncProgressViewHidden() { progressHidden += 1 }
    func showSyncInProgressDialog() { inProgressDialogs += 1 }
    func showFailedToSyncIn() { syncFailures += 1 }
    func showSwipeUpInstruction() { swipeHints += 1 }
    func showSyncConfirmationDialog(for snapshot: RuuviTagCardSnapshot) { syncConfirmations.append(snapshot.id) }
    func showSyncAbortAlert(source: GraphHistoryAbortSyncSource) { aborts.append(source) }
    func showSyncAbortAlertForSwipe(to index: Int) { swipeAborts.append(index) }
    func showExportSheet(with path: URL) { exports.append(path) }
    func showLongerHistoryDialog() { longerHistory += 1 }
    func showGraphLongPressTutorialDialog() { tutorials += 1 }
}
