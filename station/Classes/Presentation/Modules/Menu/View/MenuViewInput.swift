import Foundation

protocol MenuViewInput: ViewInput {
    var isNetworkHidden: Bool { get set }
    var viewModel: MenuViewModel? { get  set }
}
