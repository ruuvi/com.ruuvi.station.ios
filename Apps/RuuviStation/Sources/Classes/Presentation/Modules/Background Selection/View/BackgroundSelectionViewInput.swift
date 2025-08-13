import Foundation

protocol BackgroundSelectionViewInput: ViewInput {
    var viewModel: BackgroundSelectionViewModel? { get set }
    func viewShouldDismiss()
}
