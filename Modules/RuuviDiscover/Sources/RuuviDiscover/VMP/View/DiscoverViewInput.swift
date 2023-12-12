import Foundation
import RuuviLocalization
import RuuviOntology
import UIKit

protocol DiscoverViewInput: UIViewController {
    var ruuviTags: [DiscoverRuuviTagViewModel] { get set }
    var isBluetoothEnabled: Bool { get set }
    var isCloseEnabled: Bool { get set }

    func showBluetoothDisabled(userDeclined: Bool)
    func startNFCSession()
    func stopNFCSession()
    // swiftlint:disable:next function_parameter_count
    func showSensorDetailsDialog(
        for tag: NFCSensor?,
        message: String,
        showAddSensor: Bool,
        showGoToSensor: Bool,
        showUpgradeFirmware: Bool,
        isDF3: Bool
    )
}
