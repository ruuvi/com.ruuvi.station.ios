import Foundation

protocol OwnerViewInput: ViewInput {
    var mode: OwnershipMode { get set }
    func showSensorAlreadyClaimedDialog()
    func showFirmwareUpdateDialog()
    func showFirmwareDismissConfirmationUpdateDialog()
}
