import Foundation

protocol RuuviCloudViewInput: ViewInput {
    var viewModels: [RuuviCloudViewModel] { get set }
}
