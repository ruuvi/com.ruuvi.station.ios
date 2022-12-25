import Foundation
import RuuviOntology

protocol DashboardViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerAddSensors()
    func viewDidTriggerMenu()
    func viewDidTriggerBuySensors()
    func viewDidTriggerOpenCardImageView(for viewModel: CardsViewModel?)
    func viewDidTriggerSettings(for viewModel: CardsViewModel, with scrollToAlert: Bool)
    func viewDidTriggerChart(for viewModel: CardsViewModel)
    func viewDidTriggerChangeBackground(for viewModel: CardsViewModel)
    func viewDidConfirmToKeepConnectionChart(to viewModel: CardsViewModel)
    func viewDidDismissKeepConnectionDialogChart(for viewModel: CardsViewModel)
    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel, scrollToAlert: Bool)
    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel, scrollToAlert: Bool)
    func viewDidChangeDashboardType(dashboardType: DashboardType)
}
