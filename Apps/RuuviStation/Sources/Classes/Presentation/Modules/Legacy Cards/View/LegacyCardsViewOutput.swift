import Foundation

protocol LegacyCardsViewOutput {
    var showingChart: Bool { get set }
    func viewDidLoad()
    func viewWillAppear()
    func viewDidAppear()
    func viewWillDisappear()
    func viewDidScroll(to viewModel: LegacyCardsViewModel)
    func viewDidTriggerSettings(for viewModel: LegacyCardsViewModel)
    func viewDidTriggerShowChart(for viewModel: LegacyCardsViewModel)
    func viewDidTriggerNavigateChart(to viewModel: LegacyCardsViewModel)
    func viewDidTriggerDismissChart(for viewModel: LegacyCardsViewModel, dismissParent: Bool)
    func viewDidConfirmToKeepConnectionChart(to viewModel: LegacyCardsViewModel)
    func viewDidDismissKeepConnectionDialogChart(for viewModel: LegacyCardsViewModel)
    func viewDidConfirmToKeepConnectionSettings(to viewModel: LegacyCardsViewModel)
    func viewDidDismissKeepConnectionDialogSettings(for viewModel: LegacyCardsViewModel)
    func viewDidTriggerFirmwareUpdateDialog(for viewModel: LegacyCardsViewModel)
    func viewDidConfirmFirmwareUpdate(for viewModel: LegacyCardsViewModel)
    /// Trigger this method when user cancel the legacy firmware update dialog for the first time
    func viewDidIgnoreFirmwareUpdateDialog(for viewModel: LegacyCardsViewModel)
    /// Trigger this method when user confirms the lagacy firmware update dialog dismiss for the second time
    func viewDidDismissFirmwareUpdateDialog(for viewModel: LegacyCardsViewModel)
    func viewShouldDismiss()
}
