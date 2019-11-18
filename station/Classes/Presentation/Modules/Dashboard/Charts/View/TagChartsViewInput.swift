import Foundation
import BTKit

protocol TagChartsViewInput: ViewInput {
    var viewModels: [TagChartsViewModel] { get set }
    
    func showBluetoothDisabled()
    func scroll(to index: Int, immediately: Bool)
    func showSyncConfirmationDialog(for viewModel: TagChartsViewModel)
    func showClearConfirmationDialog(for viewModel: TagChartsViewModel)
    func showExportSheet(with path: URL)
    func setSync(progress: BTServiceProgress?, for viewModel: TagChartsViewModel)
    func showFailedToSyncIn(desiredConnectInterval: TimeInterval)
}

extension TagChartsViewInput {
    func scroll(to index: Int) {
        scroll(to: index, immediately: false)
    }
}
