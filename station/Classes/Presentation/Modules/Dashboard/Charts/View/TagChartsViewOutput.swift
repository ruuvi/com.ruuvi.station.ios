import Foundation

protocol TagChartsViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerMenu()
    func viewDidScroll(to viewModel: TagChartsViewModel)
    func viewDidTriggerSettings(for viewModel: TagChartsViewModel)
    func viewDidTriggerDashboard(for viewModel: TagChartsViewModel)
}
