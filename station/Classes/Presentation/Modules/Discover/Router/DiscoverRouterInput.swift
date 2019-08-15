import Foundation
import BTKit

protocol DiscoverRouterInput {
    func openDashboard()
    func openRuuviWebsite()
    func openLocationPicker(output: LocationPickerModuleOutput)
    func dismiss()
}
