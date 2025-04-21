import SwiftUI
import DGCharts
import RuuviLocal
import RuuviOntology
import RuuviService
import Combine

class ChartContainerViewModel: ObservableObject {

    /// Property to hold all the chart data collections for a single RuuviTag.
    @Published var chartEntities: [NewTagChartEntity] = []

    @Published var chartEmpty: Bool = false

    /// Whether to show the chart statistics i.e. min, max, avg, latest values
    @Published var showChartStat: Bool

    /// Whether to show all available data points or just the selected window.
    @Published var showAllPoints: Bool

    /// Property to store the selected duration range in the graph
    @Published var chartDurationHours: Int

    /// Whether to show the alert range in the graph
    @Published var showAlertRangeInGraph: Bool

    /// Whether to show the compact view of the chart. In compact view chart are smaller and fits
    /// in the screen without scrolling. Available only for Tag with 3 or less sensors.
    @Published var showCompactView: Bool

    private(set) var chartViewModels: [UUID: ChartViewModel] = [:]

    @Published var isFirstEntry: Bool = false
    @Published var updateDataSet: Bool = false

    @Published var highlightedX: Double?
    @Published var scaledChart: TagChartsView?

    let measurementService: RuuviServiceMeasurement
    let settings: RuuviLocalSettings

    init(
        settings: RuuviLocalSettings,
        flags: RuuviLocalFlags,
        measurementService: RuuviServiceMeasurement
    ) {
        self.chartDurationHours = settings.chartDurationHours
        self.showAllPoints = settings.chartShowAll
        self.showChartStat = settings.chartStatsOn
        self.showCompactView = settings.compactChartView
        self.showAlertRangeInGraph = flags.showAlertsRangeInGraph
        self.measurementService = measurementService
        self.settings = settings
    }

    func getOrCreateViewModel(for entity: NewTagChartEntity) -> ChartViewModel {
        if let existingViewModel = chartViewModels[entity.id] {
            // Update existing view model with latest data if needed
            existingViewModel.updateChartEntity(entity)
            return existingViewModel
        } else {
            // Create new view model if none exists
            let newViewModel = ChartViewModel(
                entity: entity,
                parentViewModel: self
            )
            chartViewModels[entity.id] = newViewModel
            return newViewModel
        }
    }

    func updateEntity(_ entity: NewTagChartEntity) {
        if let viewModel = chartViewModels[entity.id] {
            viewModel.updateChartEntity(entity)
        }
    }

    func setChartViewData(_ data: [NewTagChartEntity]) {
        // Clean up any view models that are no longer needed
        let newIds = Set(data.map { $0.id })
        let oldIds = Set(chartViewModels.keys)

        for id in oldIds.subtracting(newIds) {
            chartViewModels.removeValue(forKey: id)
        }

        // Update chart data
        chartEntities = data
    }

    func updateHighlight(x: Double?) {
        highlightedX = x
    }

    func chartDidTranslate(_ chartView: TagChartsView) {
        scaledChart = chartView
    }
}
