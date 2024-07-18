import Foundation

protocol SensorForceClaimViewInput: ViewInput {
    func startNFCSession()
    func stopNFCSession()
    func hideNFCButton()
    func showGATTConnectionTimeoutDialog()
    func showWrongTagScanDialog()
}
