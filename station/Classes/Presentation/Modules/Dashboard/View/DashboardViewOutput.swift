import Foundation

protocol DashboardViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidAppear()
    func viewDidTriggerMenu()
    func viewDidTriggerSettings(for viewModel: DashboardTagViewModel)
    func viewDidTapOnRSSI(for viewModel: DashboardTagViewModel)
    func viewDidAskToRemove(webTag: WebTagRealm)
}
