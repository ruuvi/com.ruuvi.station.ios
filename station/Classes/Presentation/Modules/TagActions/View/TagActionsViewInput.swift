import Foundation
import BTKit

protocol TagActionsViewInput: ViewInput {
    var viewModel: TagActionsViewModel! { get set }
    var syncProgress: BTServiceProgress? { get set }
    
    func showClearConfirmationDialog()
    func showSyncConfirmationDialog()
    func showExportSheet(with path: URL)
}
