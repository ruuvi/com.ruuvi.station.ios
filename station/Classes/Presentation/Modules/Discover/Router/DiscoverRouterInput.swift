import Foundation
import BTKit

protocol DiscoverRouterInput {
    func openCards()
    func openRuuviWebsite()
    func openLocationPicker(output: LocationPickerModuleOutput)
    func openAddUsingMac(output: AddMacModuleOutput,
                         for provider: RuuviNetworkProvider)
    func dismiss(completion: (() -> Void)?)
}

extension DiscoverRouterInput {
    func dismiss() {
        return dismiss(completion: nil)
    }
}
