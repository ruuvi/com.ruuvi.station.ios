import DGCharts
import Foundation
import RuuviLocal
import RuuviOntology

/// A custom selection is session-only; rolling selections use the existing saved preference.
enum RuuviGraphHistorySession {
    static var customSelection: RuuviHistorySelection?
    static func selection(settings: RuuviLocalSettings) -> RuuviHistorySelection {
        customSelection ?? .rolling(hours: settings.chartShowAll ? 0 : settings.chartDurationHours)
    }
}

/// Carries raw-reading statistics separately from the sampled display points.
final class RuuviHistoryChartData: LineChartData {
    let selectedRange: RuuviHistoryRange
    let sampledRange: RuuviHistoryRange
    let statistics: RuuviHistoryStatistics?

    required init() {
        selectedRange = .retained()
        sampledRange = selectedRange
        statistics = nil
        super.init()
    }

    required init(arrayLiteral elements: ChartDataSetProtocol...) {
        selectedRange = .retained()
        sampledRange = selectedRange
        statistics = nil
        super.init(dataSets: elements)
    }

    init(
        series: RuuviHistorySeries,
        selectedRange: RuuviHistoryRange,
        sampledRange: RuuviHistoryRange,
        upper: Double?,
        lower: Double?,
        showAlerts: Bool,
        drawDots: Bool
    ) {
        self.selectedRange = selectedRange
        self.sampledRange = sampledRange
        statistics = series.statistics
        let groups = Dictionary(grouping: series.points, by: \.segment)
        let sets = groups.keys.sorted().map { segment -> LineChartDataSet in
            let points = groups[segment] ?? []
            let entries = points.map { ChartDataEntry(x: $0.timestamp, y: $0.value) }
            let set = RuuviGraphDataSetFactory.newDataSet(
                upperAlertValue: upper,
                entries: entries,
                lowerAlertValue: lower,
                showAlertRangeInGraph: showAlerts
            )
            // Gaps were detected on raw readings. Sample spacing must never create a gap.
            set.showGapBetweenPoints = false
            set.drawCirclesEnabled = drawDots || entries.count == 1
            set.circleRadius = entries.count == 1 ? 1.5 : 0.8
            return set
        }
        super.init(dataSets: sets)
    }
}

/// Coalesces page notifications without postponing progress until the download ends.
/// All calls and refreshes are confined to the main queue.
final class RuuviGraphHistoryRefresh {
    private let interval: TimeInterval
    private let refresh: () -> Void
    private var pending: DispatchWorkItem?
    private var generation = 0

    init(interval: TimeInterval = 1, refresh: @escaping () -> Void) {
        self.interval = interval
        self.refresh = refresh
    }

    deinit { pending?.cancel() }

    func schedule() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard pending == nil else { return }
        let expected = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, generation == expected else { return }
            pending = nil
            refresh()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
    }

    func flush() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard pending != nil else { return }
        cancel()
        refresh()
    }

    func cancel() {
        dispatchPrecondition(condition: .onQueue(.main))
        generation += 1
        pending?.cancel()
        pending = nil
    }
}
