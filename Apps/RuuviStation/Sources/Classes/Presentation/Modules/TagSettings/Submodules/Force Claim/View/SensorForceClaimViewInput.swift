import Foundation
import RuuviOntology

protocol SensorForceClaimViewInput: ViewInput {
    var deviceType: RuuviDeviceType { get set }
    func startNFCSession()
    func stopNFCSession()
    func hideNFCButton()
    func showGATTConnectionTimeoutDialog()
    func showWrongTagScanDialog()
}
