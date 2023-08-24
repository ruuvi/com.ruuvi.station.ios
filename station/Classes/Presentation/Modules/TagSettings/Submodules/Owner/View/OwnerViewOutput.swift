import Foundation
import RuuviOntology

protocol OwnerViewOutput: AnyObject {
    func viewDidTapOnClaim(mode: OwnershipMode)
    func updateOwnerInfo(with email: String)
    func viewDidTriggerFirmwareUpdateDialog()
    func viewDidConfirmFirmwareUpdate()
    /// Trigger this method when user cancel the legacy firmware update dialog for the first time
    func viewDidIgnoreFirmwareUpdateDialog()
    func viewDidDismiss()
}
