import Foundation

protocol CardsViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidAppear()
    func viewWillDisappear()
    func viewDidScroll(to viewModel: CardsViewModel)
    func viewDidTriggerSettings(for viewModel: CardsViewModel)
    func viewDidTriggerShowChart(for viewModel: CardsViewModel)
    func viewDidTriggerDismissChart(for viewModel: CardsViewModel, dismissParent: Bool)
    func viewDidConfirmToKeepConnectionChart(to viewModel: CardsViewModel)
    func viewDidDismissKeepConnectionDialogChart(for viewModel: CardsViewModel)
    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel)
    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel)
    func viewDidTriggerFirmwareUpdateDialog(for viewModel: CardsViewModel)
    func viewDidConfirmFirmwareUpdate(for viewModel: CardsViewModel)
    /// Trigger this method when user cancel the legacy firmware update dialog for the first time
    func viewDidIgnoreFirmwareUpdateDialog(for viewModel: CardsViewModel)
    /// Trigger this method when user confirms the lagacy firmware update dialog dismiss for the second time
    func viewDidDismissFirmwareUpdateDialog(for viewModel: CardsViewModel)
    func viewShouldDismiss()
}
