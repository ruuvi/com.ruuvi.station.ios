import Foundation

protocol WebTagSettingsViewOutput {
    func viewDidAskToDismiss()
    func viewDidAskToRandomizeBackground()
    func viewDidAskToSelectBackground()
    func viewDidChangeTag(name: String)
    func viewDidAskToRemoveWebTag()
    func viewDidConfirmTagRemoval()
    func viewDidAskToSelectLocation()
    func viewDidAskToClearLocation()
}
