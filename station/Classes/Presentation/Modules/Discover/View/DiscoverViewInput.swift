import Foundation
import RuuviOntology
import RuuviVirtual

protocol DiscoverViewInput: ViewInput {
    var devices: [DiscoverRuuviTagViewModel] { get set }
    var savedDevicesIds: [AnyLocalIdentifier?] { get set }
    var webTags: [DiscoverVirtualTagViewModel] { get set }
    var savedWebTagProviders: [VirtualProvider] { get set }
    var isBluetoothEnabled: Bool { get set }
    var isCloseEnabled: Bool { get set }

    func showBluetoothDisabled()
    func showWebTagInfoDialog()
}
