import SwiftUI
import DGCharts
import RuuviLocal
import RuuviOntology
import RuuviService
import UIKit

struct SensorGraphView: UIViewRepresentable, Equatable {
    @ObservedObject var viewModel: SensorGraphViewModel
    @ObservedObject var chartContainerModel: SensorGraphContainerViewModel

    static func == (lhs: SensorGraphView, rhs: SensorGraphView) -> Bool {
        return lhs.viewModel.id == rhs.viewModel.id
    }

    func makeUIView(context: Context) -> TagChartsView {
        let chartView = TagChartsView()
        chartView.chartDelegate = context.coordinator
        updateChartDataIfNeeded(chartView, force: true)
        return chartView
    }

    func updateUIView(_ chartView: TagChartsView, context: Context) {
        updateChartDataIfNeeded(chartView)
        syncHighlighting(chartView)
        syncScaling(chartView)
    }

    private func syncHighlighting(_ chartView: TagChartsView) {
        if let x = chartContainerModel.highlightedX {
            let highlight = Highlight(x: x, y: 0, dataSetIndex: 0)
            chartView.underlyingView
                .highlightValue(highlight, callDelegate: false)
        } else {
            chartView.underlyingView.highlightValues(nil)
        }
    }

    private func syncScaling(_ chartView: TagChartsView) {
        if let sourceChart = chartContainerModel.scaledChart,
           chartContainerModel.scaledChart != chartView {
            let sourceMatrix = sourceChart.underlyingView.viewPortHandler.touchMatrix
            var targetMatrix = chartView.underlyingView.viewPortHandler.touchMatrix
            targetMatrix.a = sourceMatrix.a
            targetMatrix.tx = sourceMatrix.tx
            chartView.underlyingView.viewPortHandler.refresh(
                newMatrix: targetMatrix,
                chart: sourceChart.underlyingView,
                invalidate: true
            )
        }
    }

    private func updateChartDataIfNeeded(_ chartView: TagChartsView, force: Bool = false) {
        // Set chart title and unit
        chartView.setChartLabel(
            with: viewModel.graphTitle,
            type: viewModel.graphEntity.graphType,
            unit: viewModel.unit
        )

        //  Only set chart data if it changed or force update
        if force || viewModel.graphEntity.graphData?.dataSets.count !=
            chartView.underlyingView.data?.dataSets.count {
            chartView.setChartData(from: viewModel.graphEntity.graphData)
        }

        if viewModel.parentViewModel.updateDataSet {
            print(
                "updateDataSet",
                viewModel.graphEntity.ruuviTagId,
                viewModel.graphEntity.graphType,
                viewModel.graphEntity.dataSet.count
            )
        }

        // Set alert limits
        chartView.setAlertLimit(
            lower: viewModel.graphEntity.lowerAlertValue,
            upper: viewModel.graphEntity.upperAlertValue
        )

        // Configure chart
        chartView.setChartConfiguration(
            showAll: viewModel.parentViewModel.showAllPoints,
            durationHours: viewModel.parentViewModel.chartDurationHours
        )

        // Apply other settings
        chartView.localize()
        chartView.setYAxisLimit(
            min: viewModel.graphEntity.graphData?.yMin ?? 0,
            max: viewModel.graphEntity.graphData?.yMax ?? 0
        )
        chartView.setXAxisRenderer()
        chartView.setChartStatVisible(show: viewModel.parentViewModel.showChartStat)

        calculateMinMaxForChart(for: chartView)
    }

    private func calculateMinMaxForChart(for view: TagChartsView) {
        if let data = view.underlyingView.data,
           let dataSet = data.dataSets.first as? LineChartDataSet {
            let lowestVisibleX = view.underlyingView.lowestVisibleX
            let highestVisibleX = view.underlyingView.highestVisibleX

            var minVisibleYValue = Double.greatestFiniteMagnitude
            var maxVisibleYValue = -Double.greatestFiniteMagnitude

            dataSet.entries.forEach { entry in
                if entry.x >= lowestVisibleX, entry.x <= highestVisibleX {
                    minVisibleYValue = min(minVisibleYValue, entry.y)
                    maxVisibleYValue = max(maxVisibleYValue, entry.y)
                }
            }

            let averageYValue = calculateVisibleAverage(
                chartView: view.underlyingView,
                dataSet: dataSet
            )

            if minVisibleYValue == Double.greatestFiniteMagnitude {
                minVisibleYValue = 0
            }
            if maxVisibleYValue == -Double.greatestFiniteMagnitude {
                maxVisibleYValue = 0
            }

            view.setChartStat(
                min: minVisibleYValue,
                max: maxVisibleYValue,
                avg: averageYValue,
                type: viewModel.graphEntity.graphType,
                measurementService: viewModel.parentViewModel.measurementService
            )
        }
    }

    private func calculateVisibleAverage(chartView: LineChartView, dataSet: LineChartDataSet) -> Double {
        // Get the x-values defining the visible range of the chart.
        let lowestVisibleX = chartView.lowestVisibleX
        let highestVisibleX = chartView.highestVisibleX

        // Filter out the entries that lie within the visible range.
        let visibleEntries = dataSet.entries.filter { $0.x >= lowestVisibleX && $0.x <= highestVisibleX }

        // If there are no visible entries, return an average of 0.
        guard !visibleEntries.isEmpty else { return 0.0 }

        var totalArea = 0.0
        // Compute the area under the curve for each pair of consecutive points.
        for i in 1 ..< visibleEntries.count {
            let x1 = visibleEntries[i - 1].x
            let y1 = visibleEntries[i - 1].y
            let x2 = visibleEntries[i].x
            let y2 = visibleEntries[i].y

            // Calculate the area of the trapezium formed by two consecutive data points.
            let area = (x2 - x1) * (y1 + y2) / 2.0
            totalArea += area
        }

        // Calculate the width of the visible x-range.
        let timeSpan = visibleEntries.last!.x - visibleEntries.first!.x

        // If all visible data points have the same x-value, simply return the average of their y-values.
        if timeSpan == 0 {
            return visibleEntries.map(\.y).reduce(0, +) / Double(visibleEntries.count)
        }

        // Compute the average using the trapezoidal rule.
        return totalArea / timeSpan
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, TagChartsViewDelegate {

        var parent: SensorGraphView

        init(_ parent: SensorGraphView) {
            self.parent = parent
        }

        func chartDidTranslate(_ chartView: TagChartsView) {
            parent.chartContainerModel.chartDidTranslate(chartView)
        }

        func chartValueDidSelect(
            _ chartView: TagChartsView,
            entry: ChartDataEntry,
            highlight: Highlight
        ) {
            parent.chartContainerModel.updateHighlight(x: entry.x)
        }

        func chartValueDidDeselect(_ chartView: TagChartsView) {
            parent.chartContainerModel.updateHighlight(x: nil)
        }
    }
}
