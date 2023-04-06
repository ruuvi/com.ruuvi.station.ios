import UIKit
import RuuviOntology

protocol TagSettingsViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidAskToDismiss()
    func viewDidTriggerChangeBackground()
    func viewDidAskToRemoveRuuviTag()
    func viewDidConfirmTagRemoval()
    func viewDidChangeTag(name: String)
    func viewDidTapOnMacAddress()
    func viewDidTapOnTxPower()
    func viewDidTapOnMeasurementSequenceNumber()
    func viewDidTapOnNoValuesView()
    func viewDidTapShareButton()
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

    // Connection
    func viewDidTriggerKeepConnection(isOn: Bool)
}
