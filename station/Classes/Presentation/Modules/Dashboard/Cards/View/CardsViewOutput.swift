import Foundation

protocol CardsViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerMenu()
    func viewDidScroll(to viewModel: CardsViewModel)
    func viewDidTriggerSettings(for viewModel: CardsViewModel)
    func viewDidTriggerChart(for viewModel: CardsViewModel)
}
