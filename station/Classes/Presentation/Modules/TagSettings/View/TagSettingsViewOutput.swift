import Foundation

protocol TagSettingsViewOutput {
    func viewDidAskToDismiss()
    func viewDidAskToRandomizeBackground()
    func viewDidAskToRemoveRuuviTag()
    func viewDidConfirmTagRemoval()
    func viewDidAskToCalibrateHumidity()
}
