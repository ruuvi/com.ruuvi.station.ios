import Foundation
import RuuviOntology
import RuuviVirtual

protocol DiscoverViewInput: ViewInput {
    var devices: [DiscoverDeviceViewModel] { get set }
    var savedDevicesIds: [AnyLocalIdentifier?] { get set }
    var webTags: [DiscoverWebTagViewModel] { get set }
    var savedWebTagProviders: [VirtualProvider] { get set }
    var isBluetoothEnabled: Bool { get set }
    var isCloseEnabled: Bool { get set }

    func showBluetoothDisabled()
    func showWebTagInfoDialog()
}
