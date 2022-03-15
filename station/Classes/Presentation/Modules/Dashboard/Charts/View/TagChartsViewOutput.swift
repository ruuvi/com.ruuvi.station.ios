import Foundation
import UIKit

protocol TagChartsViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTransition()
    func viewDidTriggerMenu()
    func viewDidTriggerSettings(for viewModel: TagChartsViewModel, scrollToAlert: Bool)
    func viewDidTriggerCards(for viewModel: TagChartsViewModel)
    func viewDidTriggerSync(for viewModel: TagChartsViewModel)
    func viewDidTriggerClear(for viewModel: TagChartsViewModel)
    func viewDidConfirmToClear(for viewModel: TagChartsViewModel)
    func viewDidLocalized()
}
