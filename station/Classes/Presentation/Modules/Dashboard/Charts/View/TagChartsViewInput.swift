import Foundation
import BTKit
import Charts
import RuuviLocal

protocol TagChartsViewInput: ViewInput {
    var viewModel: TagChartsViewModel { get set }
    var viewIsVisible: Bool { get }
    func createChartViews(from: [MeasurementType])
    func clearChartHistory()
    func setChartViewData(from chartViewData: [TagChartViewData],
                          settings: RuuviLocalSettings)
    func updateChartViewData(temperatureEntries: [ChartDataEntry],
                             humidityEntries: [ChartDataEntry],
                             pressureEntries: [ChartDataEntry],
                             isFirstEntry: Bool,
                             settings: RuuviLocalSettings)
    func showBluetoothDisabled()
    func handleClearSyncButtons(connectable: Bool, isSyncing: Bool)
    func showClearConfirmationDialog(for viewModel: TagChartsViewModel)
    func setSync(progress: BTServiceProgress?, for viewModel: TagChartsViewModel)
    func setSyncProgressViewHidden()
    func showFailedToSyncIn(connectionTimeout: TimeInterval)
    func showFailedToServeIn(serviceTimeout: TimeInterval)
    func showSwipeUpInstruction()
    func showSyncAbortAlert(dismiss: Bool)
}
