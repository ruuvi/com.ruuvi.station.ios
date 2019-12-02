import Foundation
import RealmSwift
import BTKit

protocol CardsViewInput: ViewInput {
    var viewModels: [CardsViewModel] { get set }

    func scroll(to index: Int, immediately: Bool)
    func showBluetoothDisabled()
    func showSwipeLeftRightHint()
    func showWebTagAPILimitExceededError()
    func showKeepConnectionDialog(for viewModel: CardsViewModel)
}

extension CardsViewInput {
    func scroll(to index: Int) {
        scroll(to: index, immediately: false)
    }
}
