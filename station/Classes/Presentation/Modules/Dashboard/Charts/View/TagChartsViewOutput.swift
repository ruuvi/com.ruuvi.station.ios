import Foundation
import UIKit

protocol TagChartsViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewWillTransition(to orientation: UIInterfaceOrientation)
    func viewDidTriggerMenu()
    func viewDidScroll(to viewModel: TagChartsViewModel)
    func viewDidTriggerSettings(for viewModel: TagChartsViewModel)
    func viewDidTriggerCards(for viewModel: TagChartsViewModel)
    func viewDidTriggerSync(for viewModel: TagChartsViewModel)
    func viewDidTriggerExport(for viewModel: TagChartsViewModel)
    func viewDidTriggerClear(for viewModel: TagChartsViewModel)
    func viewDidConfirmToSync(for viewModel: TagChartsViewModel)
    func viewDidConfirmToClear(for viewModel: TagChartsViewModel)
}
