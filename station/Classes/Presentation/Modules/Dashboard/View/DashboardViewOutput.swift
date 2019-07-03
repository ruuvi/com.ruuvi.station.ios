import Foundation

protocol DashboardViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidAppear()
    func viewDidTriggerMenu()
    func viewDidTriggerSettings(for viewModel: DashboardRuuviTagViewModel)
    func viewDidTapOnRSSI(for viewModel: DashboardRuuviTagViewModel)
}
