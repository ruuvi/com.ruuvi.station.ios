import Foundation
import BTKit
import Charts

protocol TagChartsViewInput: ViewInput {
    var viewModel: TagChartsViewModel { get set }
    var viewIsVisible: Bool { get }
    func setupChartViews(chartViews: [TagChartView])
    func showBluetoothDisabled()
    func handleClearSyncButtons(cloudSensor: Bool, sharedSensor: Bool, isSyncing: Bool)
    func showClearConfirmationDialog(for viewModel: TagChartsViewModel)
    func setSync(progress: BTServiceProgress?, for viewModel: TagChartsViewModel)
    func setSyncProgressViewHidden()
    func showFailedToSyncIn(connectionTimeout: TimeInterval)
    func showFailedToServeIn(serviceTimeout: TimeInterval)
    func showSwipeUpInstruction()
}
