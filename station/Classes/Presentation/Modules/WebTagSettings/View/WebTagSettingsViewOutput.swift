import UIKit

protocol WebTagSettingsViewOutput {
    func viewWillAppear()
    func viewDidAskToDismiss()
    func viewDidAskToRandomizeBackground()
    func viewDidAskToSelectBackground(sourceView: UIView)
    func viewDidChangeTag(name: String)
    func viewDidAskToRemoveWebTag()
    func viewDidConfirmTagRemoval()
    func viewDidAskToSelectLocation()
    func viewDidAskToClearLocation()
    func viewDidConfirmToClearLocation()
    func viewDidTapOnAlertsDisabledView()
}
