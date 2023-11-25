import Foundation
import UIKit
import RuuviOntology
import RuuviLocalization

protocol DiscoverViewInput: UIViewController, Localizable {
    var ruuviTags: [DiscoverRuuviTagViewModel] { get set }
    var isBluetoothEnabled: Bool { get set }
    var isCloseEnabled: Bool { get set }

    func showBluetoothDisabled(userDeclined: Bool)
    func startNFCSession()
    func stopNFCSession()
    func showSensorDetailsDialog(
        for tag: NFCSensor?,
        message: String,
        showAddSensor: Bool,
        showGoToSensor: Bool,
        isDF3: Bool
    )
}
