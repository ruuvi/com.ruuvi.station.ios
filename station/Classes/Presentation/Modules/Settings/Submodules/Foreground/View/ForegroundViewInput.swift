import Foundation

protocol ForegroundViewInput: ViewInput {
    var viewModels: [ForegroundViewModel] { get set }
}
