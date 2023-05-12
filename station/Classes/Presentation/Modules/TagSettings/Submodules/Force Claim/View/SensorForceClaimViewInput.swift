import Foundation

protocol SensorForceClaimViewInput: ViewInput {
    func startNFCSession()
    func stopNFCSession()
    func enableScanButton()
    func disableScanButton()
    func hideNFCButton()
    func showGATTConnectionTimeoutDialog()
}
