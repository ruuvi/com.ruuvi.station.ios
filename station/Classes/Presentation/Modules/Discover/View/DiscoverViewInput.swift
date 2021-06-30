import Foundation
import RuuviOntology
import RuuviVirtual

protocol DiscoverViewInput: ViewInput {
    var ruuviTags: [DiscoverRuuviTagViewModel] { get set }
    var savedRuuviTagIds: [AnyLocalIdentifier?] { get set }
    var virtualTags: [DiscoverVirtualTagViewModel] { get set }
    var savedWebTagProviders: [VirtualProvider] { get set }
    var isBluetoothEnabled: Bool { get set }
    var isCloseEnabled: Bool { get set }

    func showBluetoothDisabled()
    func showWebTagInfoDialog()
}
