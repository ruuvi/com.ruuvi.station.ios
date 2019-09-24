import Foundation

protocol TagChartsViewInput: ViewInput {
    var viewModels: [TagChartsViewModel] { get set }
    
    func showBluetoothDisabled()
    func showSyncConfirmationDialog(with viewModel: TagChartsViewModel)
    func showDeleteHistoryConfirmationDialog(for viewModel: TagChartsViewModel)
    func showDisconnected(from viewModel: TagChartsViewModel)
    func scroll(to index: Int, immediately: Bool)
}

extension TagChartsViewInput {
    func scroll(to index: Int) {
        scroll(to: index, immediately: false)
    }
}
