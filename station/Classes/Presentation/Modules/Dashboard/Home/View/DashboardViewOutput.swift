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
    func viewDidTriggerSettings(for viewModel: CardsViewModel)
    func viewDidTriggerChart(for viewModel: CardsViewModel)
    func viewDidTriggerChangeBackground(for viewModel: CardsViewModel)
    func viewDidTriggerShare(for viewModel: CardsViewModel)
    func viewDidTriggerDashboardCard(for viewModel: CardsViewModel)
    func viewDidConfirmToKeepConnectionChart(to viewModel: CardsViewModel)
    func viewDidDismissKeepConnectionDialogChart(for viewModel: CardsViewModel)
    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel)
    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel)
    func viewDidChangeDashboardType(dashboardType: DashboardType)
    func viewDidChangeDashboardTapAction(type: DashboardTapActionType)
    func viewDidTriggerPullToRefresh()
}
