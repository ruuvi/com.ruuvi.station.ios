import UIKit
import RuuviOntology

protocol TagSettingsViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidAskToDismiss()
    func viewDidConfirmClaimTag()
    func viewDidTriggerChangeBackground()
    func viewDidAskToRemoveRuuviTag()
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

    // Alerts
    func viewDidChangeAlertState(for type: AlertType, isOn: Bool)
    func viewDidChangeAlertLowerBound(for type: AlertType, lower: CGFloat)
    func viewDidChangeAlertUpperBound(for type: AlertType, upper: CGFloat)
    func viewDidChangeCloudConnectionAlertUnseenDuration(duration: Int)
    func viewDidChangeAlertDescription(for type: AlertType, description: String?)

    // Offset Correction
    func viewDidTapTemperatureOffsetCorrection()
    func viewDidTapHumidityOffsetCorrection()
    func viewDidTapOnPressureOffsetCorrection()

    // Update firmware
    func viewDidTapOnUpdateFirmware()

    // Connection
    func viewDidTriggerKeepConnection(isOn: Bool)
}
