import Foundation
import RealmSwift

protocol DashboardViewInput: ViewInput {
    var temperatureUnit: TemperatureUnit { get set }
    var ruuviTags: Results<RuuviTagRealm>? { get set }
}
