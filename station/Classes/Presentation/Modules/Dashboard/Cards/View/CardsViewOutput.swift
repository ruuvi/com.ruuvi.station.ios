import Foundation

protocol CardsViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerAddSensors()
    func viewDidTriggerMenu()
    func viewDidScroll(to viewModel: CardsViewModel)
    func viewDidSetOpeningCard()
    func viewDidTriggerSettings(for viewModel: CardsViewModel, with scrollToAlert: Bool)
    func viewDidTriggerChart(for viewModel: CardsViewModel)
    func viewDidConfirmToKeepConnectionChart(to viewModel: CardsViewModel)
    func viewDidDismissKeepConnectionDialogChart(for viewModel: CardsViewModel)
    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel, scrollToAlert: Bool)
    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel, scrollToAlert: Bool)
    func viewDidTriggerFirmwareUpdateDialog(for viewModel: CardsViewModel)
    func viewDidConfirmFirmwareUpdate(for viewModel: CardsViewModel)
    /// Trigger this method when user cancel the legacy firmware update dialog for the first time
    func viewDidIgnoreFirmwareUpdateDialog(for viewModel: CardsViewModel)
    /// Trigger this method when user confirms the lagacy firmware update dialog dismiss for the second time
    func viewDidDismissFirmwareUpdateDialog(for viewModel: CardsViewModel)
}
