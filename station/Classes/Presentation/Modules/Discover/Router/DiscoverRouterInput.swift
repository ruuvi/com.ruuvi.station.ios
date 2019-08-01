import Foundation
import BTKit

protocol DiscoverRouterInput {
    func open(ruuviTag: RuuviTag)
    func openDashboard()
    func openRuuviWebsite()
    func openLocationPicker(output: LocationPickerModuleOutput)
    func dismiss()
}
