import Foundation

protocol NetworkSettingsViewOutput {
    func viewDidLoad()
    func viewDidEnterApiKey(_ apiKey: String?)
    func viewDidTriggerNetworkFeatureSwitch(_ state: Bool)
    func viewDidTriggerWhereOsSwitch(_ state: Bool)
    func viewDidTriggerKaltiotSwitch(_ state: Bool)
}
