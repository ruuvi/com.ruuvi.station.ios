import Foundation
import RealmSwift

protocol DashboardViewInput: ViewInput {
    var ruuviTags: Results<RuuviTagRealm>! { get set }
}
