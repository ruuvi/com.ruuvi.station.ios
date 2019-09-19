import Foundation
import RealmSwift
import BTKit

protocol DashboardViewInput: ViewInput {
    var viewModels: [DashboardTagViewModel] { get set }
    
    func scroll(to index: Int, immediately: Bool)
    func showBluetoothDisabled()
    func showWebTagAPILimitExceededError()
}

extension DashboardViewInput {
    func scroll(to index: Int) {
        scroll(to: index, immediately: false)
    }
}
