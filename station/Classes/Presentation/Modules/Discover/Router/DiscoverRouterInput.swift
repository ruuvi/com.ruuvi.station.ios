import Foundation
import BTKit

protocol DiscoverRouterInput {
    func openCards()
    func openRuuviWebsite()
    func openLocationPicker(output: LocationPickerModuleOutput)
    func dismiss()
}
