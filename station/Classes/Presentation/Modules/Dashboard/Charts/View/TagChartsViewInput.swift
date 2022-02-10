import Foundation
import BTKit
import Charts

protocol TagChartsViewInput: ViewInput {
    var viewModel: TagChartsViewModel { get set }
    var viewIsVisible: Bool { get }
    func setupChartViews(chartViews: [TagChartView])
    func showBluetoothDisabled()
    func handleClearSyncButtons(sharedSensors: Bool, isSyncing: Bool)
    func showSyncConfirmationDialog(for viewModel: TagChartsViewModel)
    func showClearConfirmationDialog(for viewModel: TagChartsViewModel)
    func setSync(progress: BTServiceProgress?, for viewModel: TagChartsViewModel)
    func showFailedToSyncIn(connectionTimeout: TimeInterval)
    func showFailedToServeIn(serviceTimeout: TimeInterval)
    func showSwipeUpInstruction()
}
