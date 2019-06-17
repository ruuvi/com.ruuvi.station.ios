import Foundation
import BTKit

protocol DiscoverRouterInput {
    func open(ruuviTag: RuuviTag)
    func openDashboard()
    func openRuuviWebsite()
}
