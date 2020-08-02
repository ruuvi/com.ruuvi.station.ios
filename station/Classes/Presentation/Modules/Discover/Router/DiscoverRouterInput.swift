import Foundation
import BTKit

protocol DiscoverRouterInput {
    func openCards()
    func openRuuviWebsite()
    func openLocationPicker(output: LocationPickerModuleOutput)
    func openKaltiotPicker(output: KaltiotPickerModuleOutput)
    func openAddUsingMac(output: AddMacModalModuleOutput,
                         for provider: RuuviNetworkProvider)
    func dismiss(completion: (() -> Void)?)
}

extension DiscoverRouterInput {
    func dismiss() {
        return dismiss(completion: nil)
    }
}
