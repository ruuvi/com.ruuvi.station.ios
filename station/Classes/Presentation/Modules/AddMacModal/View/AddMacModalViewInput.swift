import Foundation

protocol AddMacModalViewInput: ViewInput {
    var viewModel: AddMacModalViewModel! { get set }
    func didSelectMacAddress(_ mac: String)
}
