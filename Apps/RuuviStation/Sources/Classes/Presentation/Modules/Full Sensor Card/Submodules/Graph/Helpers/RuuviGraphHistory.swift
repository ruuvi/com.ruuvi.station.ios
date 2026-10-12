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

/// Lets a scan finish despite repeated data notifications. A changed viewport,
/// sensor or unit configuration still cancels obsolete work immediately.
final class RuuviGraphHistoryScan<Key: Equatable> {
    private var key: Key?
    private var cancellation: RuuviHistoryCancellation?
    private var refreshPending = false

    func begin(_ key: Key) -> RuuviHistoryCancellation? {
        if self.key == key, cancellation?.isCancelled == false {
            refreshPending = true
            return nil
        }
        cancellation?.cancel()
        let next = RuuviHistoryCancellation()
        self.key = key
        cancellation = next
        refreshPending = false
        return next
    }

    /// A late completion from an obsolete scan cannot finish its replacement.
    func finish(_ token: RuuviHistoryCancellation) -> Bool {
        guard cancellation === token else { return false }
        let pending = refreshPending && !token.isCancelled
        key = nil
        cancellation = nil
        refreshPending = false
        return pending
    }
}

/// Synchronize time ranges even when axis labels leave different plot widths.
enum RuuviGraphHistoryViewport {
    static func synchronize(from source: LineChartView, to target: LineChartView) {
        let sourceMatrix = source.viewPortHandler.touchMatrix
        var targetMatrix = target.viewPortHandler.touchMatrix
        targetMatrix.a = sourceMatrix.a
        let sourceWidth = source.viewPortHandler.contentWidth
        let targetWidth = target.viewPortHandler.contentWidth
        targetMatrix.tx = sourceWidth > 0 ? sourceMatrix.tx * targetWidth / sourceWidth : sourceMatrix.tx
        target.viewPortHandler.refresh(newMatrix: targetMatrix, chart: target, invalidate: true)
    }
}
