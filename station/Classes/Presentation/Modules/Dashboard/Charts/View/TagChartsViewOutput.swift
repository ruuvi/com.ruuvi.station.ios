import Foundation

protocol TagChartsViewOutput {
    func viewDidTriggerDashboard()
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerMenu()
    func viewDidScroll(to index: Int)
    func viewDidTriggerSettings(for viewModel: TagChartsViewModel)
    func viewDidAskToSync(with viewModel: TagChartsViewModel)
    func viewDidConfirmToSync(with viewModel: TagChartsViewModel)
    func viewDidAskToDeleteHistory(for viewModel: TagChartsViewModel)
    func viewDidConfirmToDeleteHistory(for viewModel: TagChartsViewModel)
}
