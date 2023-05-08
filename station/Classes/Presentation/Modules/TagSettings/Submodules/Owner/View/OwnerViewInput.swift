import Foundation

protocol OwnerViewInput: ViewInput {
    func showSensorAlreadyClaimedDialog()
    func showFirmwareUpdateDialog()
    func showFirmwareDismissConfirmationUpdateDialog()
}
