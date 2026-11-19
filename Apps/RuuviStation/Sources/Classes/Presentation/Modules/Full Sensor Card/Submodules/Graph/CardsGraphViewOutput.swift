import Foundation

protocol CardsGraphViewOutput: AnyObject {
    func viewDidChangeGraphViewport(_ range: ClosedRange<Double>)
    func viewDidChangeGraphInteraction(active: Bool)
    func viewDidLoad()
    func viewWillAppear()
    func viewDidTransition()
    func viewDidStartScrolling()
    func viewDidEndScrolling()
    func viewDidTriggerSync(for snapshot: RuuviTagCardSnapshot?)
    func viewDidStartSync(for snapshot: RuuviTagCardSnapshot?)
    func viewDidTriggerDoNotShowSyncDialog()
    func viewDidAskGraphLongPressTutorialDialog()
    func viewDidTriggerDoNotShowGraphLongPressTutorialDialog()
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
    func viewDidSelectChartsPerScreen(_ count: Int)
}

extension CardsGraphViewOutput {
    func viewDidChangeGraphViewport(_ range: ClosedRange<Double>) { }
    func viewDidChangeGraphInteraction(active: Bool) { }
}
