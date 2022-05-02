import Foundation
import UIKit
import RuuviOntology
import RuuviVirtual
import RuuviLocalization

protocol DiscoverViewInput: UIViewController, Localizable {
    var ruuviTags: [DiscoverRuuviTagViewModel] { get set }
    var virtualTags: [DiscoverVirtualTagViewModel] { get set }
    var savedWebTagProviders: [VirtualProvider] { get set }
    var isBluetoothEnabled: Bool { get set }
    var isCloseEnabled: Bool { get set }

    func showBluetoothDisabled()
    func showWebTagInfoDialog()
}
