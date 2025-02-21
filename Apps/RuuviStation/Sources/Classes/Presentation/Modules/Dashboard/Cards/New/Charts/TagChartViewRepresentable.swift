import SwiftUI
import DGCharts
import RuuviLocal
import RuuviOntology
import RuuviService
import UIKit

struct TagChartViewRepresentable: UIViewRepresentable, Equatable {
    @ObservedObject var viewModel: ChartViewModel
    var chartSync: ChartSyncManager

    static func == (lhs: TagChartViewRepresentable, rhs: TagChartViewRepresentable) -> Bool {
        // Only update if the view model needs an update
        return lhs.viewModel.id == rhs.viewModel.id &&
               !lhs.viewModel.needsUpdate
    }

    func makeUIView(context: Context) -> TagChartsView {
        let chartView = TagChartsView()
        chartView.chartDelegate = context.coordinator
        chartSync.register(chartView: chartView)
        updateChartDataIfNeeded(chartView, force: true)
        return chartView
    }

    func updateUIView(_ chartView: TagChartsView, context: Context) {
//        if viewModel.needsUpdate {
//
//            // Reset the update flag after applying changes
//            DispatchQueue.main.async {
//                viewModel.needsUpdate = false
//            }
//        }

        updateChartDataIfNeeded(chartView)
    }

    private func updateChartDataIfNeeded(_ chartView: TagChartsView, force: Bool = false) {
        // Set chart title and unit
        chartView.setChartLabel(
            with: viewModel.chartTitle,
            type: viewModel.chartData.chartType,
            unit: viewModel.unit
        )

        //  Only set chart data if it changed or force update
        if force || viewModel.chartData.chartData?.dataSets.count !=
            chartView.underlyingView.data?.dataSets.count {
            chartView.setChartData(from: viewModel.chartData.chartData)
        }

        // Set alert limits
        chartView.setAlertLimit(
            lower: viewModel.chartData.lowerAlertValue,
            upper: viewModel.chartData.upperAlertValue
        )

        // Configure chart
        chartView.setChartConfiguration(
            showAll: viewModel.parenViewModel.showAllPoints,
            durationHours: viewModel.parenViewModel.chartDurationHours
        )

        // Apply other settings
        chartView.localize()
        chartView.setYAxisLimit(
            min: viewModel.chartData.chartData?.yMin ?? 0,
            max: viewModel.chartData.chartData?.yMax ?? 0
        )
        chartView.setXAxisRenderer()
        chartView.setChartStatVisible(show: viewModel.parenViewModel.showChartStat)

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
                type: viewModel.chartData.chartType,
                measurementService: viewModel.parenViewModel.measurementService
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

        var parent: TagChartViewRepresentable

        init(_ parent: TagChartViewRepresentable) {
            self.parent = parent
        }

        func chartDidTranslate(_ chartView: TagChartsView) {
            parent.chartSync.chartDidTranslate(chartView)
        }

        func chartValueDidSelect(
            _ chartView: TagChartsView,
            entry: ChartDataEntry,
            highlight: Highlight
        ) {
            parent.chartSync.chartValueDidSelect(chartView, highlight: highlight)
        }

        func chartValueDidDeselect(_ chartView: TagChartsView) {
            parent.chartSync.chartValueDidDeselect(chartView)
        }
    }
}
