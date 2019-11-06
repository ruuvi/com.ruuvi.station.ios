import Foundation

protocol DashboardViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerMenu()
    func viewDidScroll(to viewModel: DashboardTagViewModel)
    func viewDidTriggerSettings(for viewModel: DashboardTagViewModel)
    func viewDidTriggerChart(for viewModel: DashboardTagViewModel)
}
