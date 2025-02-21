import SwiftUI
import DGCharts
import RuuviLocal
import RuuviOntology
import RuuviService
import Combine

class ChartContainerViewModel: ObservableObject {

    /// Property to hold all the chart data collections,
    @Published var chartViewData: [NewTagChartViewData] = []

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

    /// The manager that syncs all TagChartsView transforms/highlights
    let chartSync: ChartSyncManager = ChartSyncManager()

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

    func getOrCreateViewModel(for chartData: NewTagChartViewData) -> ChartViewModel {
        if let existingViewModel = chartViewModels[chartData.id] {
            // Update existing view model with latest data if needed
            existingViewModel.updateChartData(chartData)
            return existingViewModel
        } else {
            // Create new view model if none exists
            let newViewModel = ChartViewModel(
                chartData: chartData,
                parentViewModel: self
            )
            chartViewModels[chartData.id] = newViewModel
            return newViewModel
        }
    }

    func setChartViewData(_ data: [NewTagChartViewData]) {
        // Clean up any view models that are no longer needed
        let newIds = Set(data.map { $0.id })
        let oldIds = Set(chartViewModels.keys)

        for id in oldIds.subtracting(newIds) {
            chartViewModels.removeValue(forKey: id)
        }

        // Update chart data
        chartViewData = data
    }
}
