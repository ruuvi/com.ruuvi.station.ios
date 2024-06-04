import BTKit
import DGCharts
import Foundation
import RuuviLocal
import RuuviOntology

protocol TagChartsViewInput: ViewInput {
    var viewModel: TagChartsViewModel { get set }
    var historyLengthInHours: Int { get set }
    var showChartStat: Bool { get set }
    var showChartAll: Bool { get set }
    var showAlertRangeInGraph: Bool { get set }
    var useNewGraphRendering: Bool { get set }
    var viewIsVisible: Bool { get }
    func createChartViews(from: [MeasurementType])
    func clearChartHistory()
    func setChartViewData(
        from chartViewData: [TagChartViewData],
        settings: RuuviLocalSettings
    )
    func updateChartViewData(
        temperatureEntries: [ChartDataEntry],
        humidityEntries: [ChartDataEntry],
        pressureEntries: [ChartDataEntry],
        isFirstEntry: Bool,
        settings: RuuviLocalSettings
    )
    func updateLatestMeasurement(
        temperature: ChartDataEntry?,
        humidity: ChartDataEntry?,
        pressure: ChartDataEntry?,
        settings: RuuviLocalSettings
    )
    func updateLatestRecordStatus(with record: RuuviTagSensorRecord)
    func showBluetoothDisabled(userDeclined: Bool)
    func showClearConfirmationDialog(for viewModel: TagChartsViewModel)
    func setSync(progress: BTServiceProgress?, for viewModel: TagChartsViewModel)
    func setSyncProgressViewHidden()
    func showFailedToSyncIn()
    func showSwipeUpInstruction()
    func showSyncConfirmationDialog(for viewModel: TagChartsViewModel)
    func showSyncAbortAlert(dismiss: Bool)
    func showSyncAbortAlertForSwipe()
    func showExportSheet(with path: URL)
    func showLongerHistoryDialog()
}
