import Foundation
import RealmSwift
import BTKit

protocol DashboardViewInput: ViewInput {
    var viewModels: [DashboardTagViewModel] { get set }
    
    func scroll(to index: Int)
    func showBluetoothDisabled()
}
