import Foundation

protocol CardsViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerMenu()
    func viewDidScroll(to viewModel: CardsViewModel)
    func viewDidTriggerSettings(for viewModel: CardsViewModel, with scrollToAlert: Bool)
    func viewDidTriggerChart(for viewModel: CardsViewModel)
    func viewDidConfirmToKeepConnection(to viewModel: CardsViewModel)
    func viewDidDismissKeepConnectionDialog(for viewModel: CardsViewModel)
}
