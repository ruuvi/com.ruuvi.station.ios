import Foundation

protocol DashboardViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerMenu()
    func viewDidTriggerSettings(for viewModel: DashboardRuuviTagViewModel)
    func viewDidAskToRemove(viewModel: DashboardRuuviTagViewModel)
    func viewDidAskToRename(viewModel: DashboardRuuviTagViewModel)
}
