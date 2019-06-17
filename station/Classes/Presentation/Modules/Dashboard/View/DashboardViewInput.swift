import Foundation
import RealmSwift
import BTKit

protocol DashboardViewInput: ViewInput {
    var temperatureUnit: TemperatureUnit { get set }
    var viewModels: [DashboardRuuviTagViewModel] { get set }
    
    func reload(viewModel: DashboardRuuviTagViewModel)
}
