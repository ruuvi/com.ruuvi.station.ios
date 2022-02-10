import Foundation

protocol ShareViewInput: ViewInput {
    var viewModel: ShareViewModel! { get set }
    func reloadTableView()
    func clearInput()
    func showInvalidEmail()
    func showSuccessfullyShared()
}
