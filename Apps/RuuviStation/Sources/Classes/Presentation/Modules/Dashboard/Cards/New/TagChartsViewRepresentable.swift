import SwiftUI
import DGCharts
import RuuviService

struct TagChartsViewRepresentable: UIViewRepresentable {
    typealias UIViewType = TagChartsView

    @Binding var chartData: NewTagChartViewData
    var chartName: String
    var measurementService: RuuviServiceMeasurement
    var unit: String
    var minValue: Double?
    var maxValue: Double?
    var avgValue: Double?
    var latestValue: ChartDataEntry?
    var dataSet: [ChartDataEntry]?

    func makeUIView(
        context: Context
    ) -> TagChartsView {
        let chartView = TagChartsView()
        chartView.underlyingView.data = chartData.chartData
        if let dataSet = dataSet {
            chartView.updateDataSet(
                with: dataSet,
                isFirstEntry: false,
                showAlertRangeInGraph: false
            )
        }
        chartView
            .setChartLabel(
                with: chartName,
                type: chartData.chartType,
                unit: unit
            )
        chartView
            .setChartStat(
                min: minValue,
                max: maxValue,
                avg: avgValue,
                type: chartData.chartType,
                measurementService: measurementService
            )
        return chartView
    }

    func updateUIView(
        _ uiView: TagChartsView,
        context: Context
    ) {
        uiView.underlyingView.data = chartData.chartData
        if let dataSet = dataSet {
            uiView.updateDataSet(
                with: dataSet,
                isFirstEntry: false,
                showAlertRangeInGraph: false
            )
        }
        uiView
            .setChartLabel(
                with: chartName,
                type: chartData.chartType,
                unit: unit
            )
        uiView
            .setChartStat(
                min: minValue,
                max: maxValue,
                avg: avgValue,
                type: chartData.chartType,
                measurementService: measurementService
            )

        if let latest = latestValue {
            uiView
                .updateLatest(
                    with: latest,
                    type: chartData.chartType,
                    measurementService: measurementService,
                    unit: unit
                )
        }
    }
}

//import SwiftUI
//import DGCharts
//import RuuviOntology
//import RuuviLocal
//import RuuviService
//import RuuviLocalization
//
//// Wrapper to manage chart synchronization
//class MultiChartSynchronizer: ObservableObject {
//    // Store references to all chart data
//    @Published var chartDataArray: [NewTagChartViewData]
//
//    // Synchronization state
//    @Published var sharedViewPortMatrix: CGAffineTransform?
//    @Published var sharedHighlight: (entry: ChartDataEntry, highlight: Highlight)?
//
//    init(chartDataArray: [NewTagChartViewData]) {
//        self.chartDataArray = chartDataArray
//    }
//
//    // Synchronize chart viewport
//    func synchronizeViewPort(_ sourceMatrix: CGAffineTransform, excludingChart: NewTagChartViewData) {
//        guard chartDataArray.count > 1 else { return }
//
//        sharedViewPortMatrix = sourceMatrix
//    }
//
//    // Synchronize chart highlight
//    func synchronizeHighlight(
//        _ entry: ChartDataEntry, _ highlight: Highlight, excludingChart: NewTagChartViewData
//    ) {
//        guard chartDataArray.count > 1 else { return }
//        sharedHighlight = (entry, highlight)
//    }
//
//    // Clear highlights across all charts
//    func clearHighlights() {
//        guard chartDataArray.count > 1 else { return }
//
//        sharedHighlight = nil
//    }
//}
//
//// Enhanced RuuviChartView to support synchronization
//struct RuuviChartView: UIViewRepresentable {
//    @ObservedObject var chartData: NewTagChartViewData
////    @ObservedObject var synchronizer: MultiChartSynchronizer
//
//    let settings: RuuviLocalSettings
//    let measurementService: RuuviServiceMeasurement
//    let flags: RuuviLocalFlags
//
//    // Configuration options
//    var showChartStat: Bool = true
//    var showAlertRangeInGraph: Bool = true
//
//    // Delegate closures
//    var onChartTranslate: (() -> Void)?
//    var onValueSelect: ((ChartDataEntry, Highlight) -> Void)?
//    var onValueDeselect: (() -> Void)?
//
//    func makeUIView(context: Context) -> TagChartsView {
//        let chartView = TagChartsView(frame: .zero)
//        chartView.chartDelegate = context.coordinator
//        return chartView
//    }
//
//    func updateUIView(_ uiView: TagChartsView, context: Context) {
//        // Existing update logic from previous implementation
//        uiView.setSettings(settings: settings)
//
//        let unit = getUnit(for: chartData.chartType, settings: settings)
//        uiView.setChartLabel(
//            with: getChartTitle(for: chartData.chartType),
//            type: chartData.chartType,
//            measurementService: measurementService,
//            unit: unit
//        )
//
////        if let chartData = chartData.chartData {
////            uiView.updateDataSet(
////                with: chartData.dataSets.first?.entries ?? [],
////                isFirstEntry: context.coordinator.isFirstEntry,
////                showAlertRangeInGraph: showAlertRangeInGraph
////            )
////
////            uiView.setYAxisLimit(
////                min: chartData.yMin,
////                max: chartData.yMax ?? 0
////            )
////        } else {
////            uiView.clearChartData()
////        }
//
//        uiView.underlyingView.lowerAlertValue = chartData.lowerAlertValue
//        uiView.underlyingView.upperAlertValue = chartData.upperAlertValue
//
//        uiView.setChartStatVisible(show: showChartStat)
//        uiView.setXAxisRenderer()
//
//        // Synchronization logic
////        if let sharedMatrix = synchronizer.sharedViewPortMatrix {
////            uiView.underlyingView.viewPortHandler.refresh(
////                newMatrix: sharedMatrix,
////                chart: uiView.underlyingView,
////                invalidate: true
////            )
////        }
//
////        // Highlight synchronization
////        if let sharedHighlight = synchronizer.sharedHighlight,
////           sharedHighlight.highlight.dataSetIndex == uiView.underlyingView.data?.dataSets.first?.index {
////            uiView.underlyingView.highlightValue(sharedHighlight.highlight)
////        } else {
////            uiView.underlyingView.highlightValue(nil)
////        }
////
////        // Existing update methods
////        if let latestEntry = chartData.chartData?.dataSets.first?.entries.last {
////            uiView.updateLatest(
////                with: latestEntry,
////                type: chartData.chartType,
////                measurementService: measurementService,
////                unit: unit
////            )
////        }
//
//        uiView.localize()
//    }
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//
//    // MARK: - Helper Methods
//    private func getUnit(for type: MeasurementType, settings: RuuviLocalSettings) -> String {
//        switch type {
//        case .temperature: return settings.temperatureUnit.symbol
//        case .humidity:
//            return settings.humidityUnit == .dew ?
//                settings.temperatureUnit.symbol :
//                settings.humidityUnit.symbol
//        case .pressure: return settings.pressureUnit.symbol
//        case .aqi: return "%"
//        case .co2: return RuuviLocalization.unitCo2
//        case .pm10: return RuuviLocalization.unitPm10
//        case .pm25: return RuuviLocalization.unitPm25
//        case .voc: return RuuviLocalization.unitVoc
//        case .nox: return RuuviLocalization.unitNox
//        case .luminosity: return RuuviLocalization.unitLuminosity
//        case .sound: return RuuviLocalization.unitSound
//        default: return ""
//        }
//    }
//
//    private func getChartTitle(for type: MeasurementType) -> String {
//        switch type {
//        case .temperature: return RuuviLocalization.TagSettings.OffsetCorrection.temperature
//        case .humidity: return RuuviLocalization.TagSettings.OffsetCorrection.humidity
//        case .pressure: return RuuviLocalization.TagSettings.OffsetCorrection.pressure
//        case .aqi: return RuuviLocalization.aqi
//        case .co2: return RuuviLocalization.co2
//        case .pm10: return RuuviLocalization.pm10
//        case .pm25: return RuuviLocalization.pm25
//        case .voc: return RuuviLocalization.voc
//        case .nox: return RuuviLocalization.nox
//        case .luminosity: return RuuviLocalization.luminosity
//        case .sound: return RuuviLocalization.sound
//        default: return ""
//        }
//    }
//
//    // MARK: - Coordinator
//    class Coordinator: NSObject, TagChartsViewDelegate {
//        var parent: RuuviChartView
//        var isFirstEntry = true
//
//        init(_ parent: RuuviChartView) {
//            self.parent = parent
//        }
//
//        func chartDidTranslate(_ chartView: TagChartsView) {
//            // Synchronize viewport across charts
//            let matrix = chartView.underlyingView.viewPortHandler.touchMatrix
////            parent.synchronizer.synchronizeViewPort(matrix, excludingChart: parent.chartData)
//            parent.onChartTranslate?()
//        }
//
//        func chartValueDidSelect(
//            _ chartView: TagChartsView,
//            entry: ChartDataEntry,
//            highlight: Highlight
//        ) {
//            // Synchronize highlight across charts
////            parent.synchronizer.synchronizeHighlight(entry, highlight, excludingChart: parent.chartData)
//
//            parent.onValueSelect?(entry, highlight)
//        }
//
//        func chartValueDidDeselect(_ chartView: TagChartsView) {
//            // Clear highlights across charts
////            parent.synchronizer.clearHighlights()
//
//            parent.onValueDeselect?()
//        }
//    }
//}
//
//// Extension to add synchronizer support
//extension NewTagChartViewData {
//    func makeChartView(
////        synchronizer: MultiChartSynchronizer,
//        settings: RuuviLocalSettings,
//        measurementService: RuuviServiceMeasurement,
//        flags: RuuviLocalFlags,
//        onChartTranslate: (() -> Void)? = nil,
//        onValueSelect: ((ChartDataEntry, Highlight) -> Void)? = nil,
//        onValueDeselect: (() -> Void)? = nil
//    ) -> RuuviChartView {
//        RuuviChartView(
//            chartData: self,
////            synchronizer: synchronizer,
//            settings: settings,
//            measurementService: measurementService,
//            flags: flags,
//            onChartTranslate: onChartTranslate,
//            onValueSelect: onValueSelect,
//            onValueDeselect: onValueDeselect
//        )
//    }
//}
