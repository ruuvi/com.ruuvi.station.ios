import Foundation
import UIKit

protocol TagChartsViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTransition()
    func viewDidTriggerSync(for viewModel: TagChartsViewModel)
    func viewDidStartSync(for viewModel: TagChartsViewModel)
    func viewDidTriggerDoNotShowSyncDialog()
    func viewDidTriggerStopSync(for viewModel: TagChartsViewModel)
    func viewDidTriggerClear(for viewModel: TagChartsViewModel)
    func viewDidConfirmToClear(for viewModel: TagChartsViewModel)
    func viewDidConfirmAbortSync(dismiss: Bool)
    func viewDidTapOnExport()
    func viewDidSelectChartHistoryLength(hours: Int)
    func viewDidSelectLongerHistory()
    func viewDidSelectTriggerChartStat(show: Bool)
}
