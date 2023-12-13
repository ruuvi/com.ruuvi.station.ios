import Foundation

protocol DashboardCellDelegate: NSObjectProtocol {
    func didTapAlertButton(for viewModel: CardsViewModel)
}
