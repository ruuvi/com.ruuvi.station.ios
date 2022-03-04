import Foundation

protocol CardsViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerMenu()
    func viewDidScroll(to viewModel: CardsViewModel)
    func viewDidTriggerSettings(for viewModel: CardsViewModel, with scrollToAlert: Bool)
    func viewDidTriggerChart(for viewModel: CardsViewModel)
    func viewDidConfirmToKeepConnectionChart(to viewModel: CardsViewModel)
    func viewDidDismissKeepConnectionDialogChart(for viewModel: CardsViewModel)
    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel, scrollToAlert: Bool)
    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel, scrollToAlert: Bool)
}
