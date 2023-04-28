import Foundation

protocol DefaultsViewInput: ViewInput {
    var viewModels: [DefaultsViewModel] { get set }
    func showEndpointChangeConfirmationDialog(useDevServer: Bool?)
}
