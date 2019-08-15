import Foundation

protocol DashboardViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerMenu()
    func viewDidTriggerSettings(for viewModel: DashboardRuuviTagViewModel)
}
