import UIKit
import RuuviOntology

protocol TagSettingsViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidAskToDismiss()
    func viewDidAskToRandomizeBackground()
    func viewDidAskToRemoveRuuviTag()
    func viewDidConfirmTagRemoval()
    func viewDidChangeTag(name: String)
    func viewDidAskToSelectBackground(sourceView: UIView)
    func viewDidTapOnMacAddress()
    func viewDidTapOnTxPower()
    func viewDidTapOnMeasurementSequenceNumber()
    func viewDidTapOnNoValuesView()
    func viewDidTapOnAlertsDisabledView()
    func viewDidAskToConnectFromAlertsDisabledDialog()
    func viewDidTapClaimButton()
    func viewDidTapShareButton()
    func viewDidTapOnBackgroundIndicator()
    func viewDidTapOnExport()
    func viewDidTapOnOwner()
    func viewDidTriggerFirmwareUpdateDialog()
    func viewDidConfirmFirmwareUpdate()
    /// Trigger this method when user cancel the legacy firmware update dialog for the first time
    func viewDidIgnoreFirmwareUpdateDialog()

    // Offset Correction
    func viewDidTapTemperatureOffsetCorrection()
    func viewDidTapHumidityOffsetCorrection()
    func viewDidTapOnPressureOffsetCorrection()

    // Update firmware
    func viewDidTapOnUpdateFirmware()
}
