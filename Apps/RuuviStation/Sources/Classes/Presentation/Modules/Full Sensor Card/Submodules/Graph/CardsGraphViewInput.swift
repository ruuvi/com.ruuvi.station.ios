import BTKit
import DGCharts
import Foundation
import RuuviLocal
import RuuviOntology

protocol CardsGraphViewInput: ViewInput {
    var historyLengthInHours: Int { get set }
    var showChartStat: Bool { get set }
    var compactChartView: Bool { get set }
    var showChartAll: Bool { get set }
    var showAlertRangeInGraph: Bool { get set }
    var viewIsVisible: Bool { get }
    func resetScrollPosition()
    func showBluetoothDisabled(userDeclined: Bool)
    func setActiveSnapshot(_ snapshot: RuuviTagCardSnapshot?)
    func createChartViews(from: [MeasurementDisplayVariant])
    func scroll(to variant: MeasurementDisplayVariant)
    func clearChartHistory()
    func setChartViewData(
        from chartViewData: [RuuviGraphViewDataModel],
        settings: RuuviLocalSettings
    )

    func updateChartViewData(
        _ entries: [MeasurementDisplayVariant: [ChartDataEntry]],
        isFirstEntry: Bool,
        firstEntry: RuuviMeasurement?,
        settings: RuuviLocalSettings
    )

    func updateLatestMeasurement(
        _ entries: [MeasurementDisplayVariant: ChartDataEntry?],
        settings: RuuviLocalSettings
    )
    func showClearConfirmationDialog(for snapshot: RuuviTagCardSnapshot)
    func setSync(progress: BTServiceProgress?, for snapshot: RuuviTagCardSnapshot)
    func setSyncProgressViewHidden()
    func showFailedToSyncIn()
    func showSwipeUpInstruction()
    func showSyncConfirmationDialog(for snapshot: RuuviTagCardSnapshot)
    func showSyncAbortAlert(source: GraphHistoryAbortSyncSource)
    func showSyncAbortAlertForSwipe(to index: Int)
    func showExportSheet(with path: URL)
    func showLongerHistoryDialog()
}
