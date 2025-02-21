import DGCharts
import Foundation

/// A shared “sync manager” that coordinates chart scrolling/panning and highlights.
public class ChartSyncManager {
    /// All currently active charts
    var chartViews: [TagChartsView] = []

    /// If you have a `showAlertRangeInGraph` or other flags, store them here
    var showAlertRangeInGraph: Bool = false

    /// Register a new chart so we can synchronize it with others.
    func register(chartView: TagChartsView) {
        guard !chartViews.contains(chartView) else { return }
        chartViews.append(chartView)
    }

    /// Deregister a chart (if one leaves the view hierarchy).
    func unregister(chartView: TagChartsView) {
        if let idx = chartViews.firstIndex(of: chartView) {
            chartViews.remove(at: idx)
        }
    }

    // MARK: - The old "sync" logic

    func chartDidTranslate(_ sourceChart: TagChartsView) {
        // If only one chart, just do local calculations, no sync needed
        guard chartViews.count > 1 else {
            sourceChartLocalCalc(sourceChart)
            return
        }

        let sourceMatrix = sourceChart.underlyingView.viewPortHandler.touchMatrix

        // 1) Update transform on other charts
        chartViews.filter { $0 != sourceChart }.forEach { otherChart in
            var targetMatrix = otherChart.underlyingView.viewPortHandler.touchMatrix
            targetMatrix.a = sourceMatrix.a
            targetMatrix.tx = sourceMatrix.tx
            otherChart.underlyingView.viewPortHandler.refresh(
                newMatrix: targetMatrix,
                chart: otherChart.underlyingView,
                invalidate: true
            )
        }

        // 2) Recalculate min/max etc. on all charts
        chartViews.forEach { view in
            sourceChartLocalCalc(view)
        }
    }

    func chartValueDidSelect(_ sourceChart: TagChartsView, highlight: Highlight) {
        // If only one chart, no sync needed
        guard chartViews.count > 1 else { return }

        chartViews
            .filter { $0 != sourceChart }
            .forEach { otherChart in
                print("Highlighting value in other chart", highlight)
                otherChart.underlyingView.highlightValue(highlight)
            }
    }

    func chartValueDidDeselect(_ sourceChart: TagChartsView) {
        guard chartViews.count > 1 else { return }

        chartViews.forEach { chart in
            chart.underlyingView.highlightValue(nil)
        }
    }

    /// Equivalent of your local “calculateMinMaxForChart(for:)” or “calculateAlertFillIfNeeded(for:)”
    private func sourceChartLocalCalc(_ chartView: TagChartsView) {
        // e.g. call your existing `calculateMinMaxForChart` logic
        // or any alert fill logic
        // if showAlertRangeInGraph { ... }
    }
}
