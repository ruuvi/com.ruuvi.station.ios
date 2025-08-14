import Foundation

protocol CardsGraphViewOutput: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func viewDidTransition()
    func viewDidStartScrolling()
    func viewDidEndScrolling()
    func viewDidTriggerSync(for snapshot: RuuviTagCardSnapshot?)
    func viewDidStartSync(for snapshot: RuuviTagCardSnapshot?)
    func viewDidTriggerDoNotShowSyncDialog()
    func viewDidTriggerStopSync(for snapshot: RuuviTagCardSnapshot?)
    func viewDidTriggerClear(for snapshot: RuuviTagCardSnapshot?)
    func viewDidConfirmToClear(for snapshot: RuuviTagCardSnapshot?)
    func viewDidConfirmAbortSync(source: GraphHistoryAbortSyncSource)
    func viewDidTapOnExportCSV()
    func viewDidTapOnExportXLSX()
    func viewDidSelectChartHistoryLength(hours: Int)
    func viewDidSelectAllChartHistory()
    func viewDidSelectLongerHistory()
    func viewDidSelectTriggerChartStat(show: Bool)
    func viewDidSelectTriggerCompactChart(showCompactChartView: Bool)
}
