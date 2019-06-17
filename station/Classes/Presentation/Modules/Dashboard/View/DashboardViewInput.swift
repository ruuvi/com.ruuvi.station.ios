import Foundation
import RealmSwift
import BTKit

protocol DashboardViewInput: ViewInput {
    var temperatureUnit: TemperatureUnit { get set }
    var ruuviTags: Results<RuuviTagRealm>? { get set }
    
    func update(ruuviTag: RuuviTagRealm, with data: RuuviTag)
}
