import Foundation

protocol TagSettingsViewOutput {
    func viewDidAskToDismiss()
    func viewDidAskToRandomizeBackground()
    func viewDidAskToRemoveRuuviTag()
    func viewDidConfirmTagRemoval()
    func viewDidAskToCalibrateHumidity()
    func viewDidChangeTag(name: String)
    func viewDidAskToSelectBackground()
    func viewDidTapOnMacAddress()
    func viewDidTapOnUUID()
}
