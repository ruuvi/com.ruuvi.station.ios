import Foundation

protocol AddMacViewInput: ViewInput {
    var viewModel: AddMacViewModel! { get set }
    func didSelectMacAddress(_ mac: String)
}
