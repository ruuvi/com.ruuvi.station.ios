import Foundation

protocol OwnerViewInput: ViewInput {
    func showSensorAlreadyClaimedError(error: String, email: String?)
    func showFirmwareUpdateDialog()
    func showFirmwareDismissConfirmationUpdateDialog()
}
