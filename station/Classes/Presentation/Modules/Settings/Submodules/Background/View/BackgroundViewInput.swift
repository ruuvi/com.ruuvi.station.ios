import Foundation

protocol BackgroundViewInput: ViewInput {
    var viewModels: [BackgroundViewModel] { get set }
}
