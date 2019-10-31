import Foundation

protocol TagActionsViewInput: ViewInput {
    var viewModel: TagActionsViewModel! { get set }
    
    func showClearConfirmationDialog()
    func showSyncConfirmationDialog()
    func showExportDialog()
}
