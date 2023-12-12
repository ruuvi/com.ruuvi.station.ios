import Foundation

protocol DevicesViewInput: ViewInput {
    var viewModels: [DevicesViewModel] { get set }
    func showTokenIdDialog(for viewModel: DevicesViewModel)
    func showTokenFetchError(with error: RUError)
}
