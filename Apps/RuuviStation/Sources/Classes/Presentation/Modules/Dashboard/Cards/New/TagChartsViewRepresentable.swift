import SwiftUI
import DGCharts
import RuuviService

struct TagChartsViewRepresentable: UIViewRepresentable {
    typealias UIViewType = TagChartsView

    var chartData: TagChartViewData
    var chartName: String
    var measurementType: MeasurementType
    var measurementService: RuuviServiceMeasurement
    var unit: String
    var minValue: Double?
    var maxValue: Double?
    var avgValue: Double?
    var latestValue: ChartDataEntry?

    func makeUIView(
        context: Context
    ) -> TagChartsView {
        let chartView = TagChartsView()
        chartView
            .setChartLabel(
                with: chartName,
                type: measurementType,
                measurementService: measurementService,
                unit: unit
            )
        chartView
            .setChartStat(
                min: minValue,
                max: maxValue,
                avg: avgValue,
                type: measurementType,
                measurementService: measurementService
            )
        return chartView
    }

    func updateUIView(
        _ uiView: TagChartsView,
        context: Context
    ) {
        uiView.underlyingView.data = chartData.chartData
        uiView
            .setChartLabel(
                with: chartName,
                type: measurementType,
                measurementService: measurementService,
                unit: unit
            )
        uiView
            .setChartStat(
                min: minValue,
                max: maxValue,
                avg: avgValue,
                type: measurementType,
                measurementService: measurementService
            )
        
        if let latest = latestValue {
            uiView
                .updateLatest(
                    with: latest,
                    type: measurementType,
                    measurementService: measurementService,
                    unit: unit
                )
        }
    }
}
