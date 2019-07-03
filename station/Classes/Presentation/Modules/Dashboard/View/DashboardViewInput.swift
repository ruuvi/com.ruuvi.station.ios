import Foundation
import RealmSwift
import BTKit

protocol DashboardViewInput: ViewInput {
    var viewModels: [DashboardRuuviTagViewModel] { get set }
    
    func scroll(to index: Int)
    func showBluetoothDisabled()
}
