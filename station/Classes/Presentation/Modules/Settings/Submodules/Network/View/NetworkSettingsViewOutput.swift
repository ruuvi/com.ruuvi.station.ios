import Foundation

protocol NetworkSettingsViewOutput {
    func viewDidLoad()
    func viewDidTriggerNetworkFeatureSwitch(_ state: Bool)
}
