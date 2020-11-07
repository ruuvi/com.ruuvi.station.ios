import Foundation

protocol ShareViewInput: ViewInput {
    var viewModel: ShareViewModel! { get set }
    func reloadSharedEmailsSection()
    func reloadTableView()
}
