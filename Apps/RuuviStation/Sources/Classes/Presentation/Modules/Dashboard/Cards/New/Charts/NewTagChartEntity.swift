import Foundation
import SwiftUI
import RuuviOntology
import DGCharts

class NewTagChartEntity: NSObject, ObservableObject {
    let id = UUID()

    @Published var ruuviTagId: String
    @Published var chartType: MeasurementType
    @Published var chartData: LineChartData?
    @Published var lowerAlertValue: Double?
    @Published var upperAlertValue: Double?
    @Published var dataSet: [ChartDataEntry] = []

    init(
        ruuviTagId: String,
        chartType: MeasurementType,
        chartData: LineChartData? = nil,
        upperAlertValue: Double? = nil,
        lowerAlertValue: Double? = nil
    ) {
        self.ruuviTagId = ruuviTagId
        self.chartType = chartType
        self.chartData = chartData
        self.upperAlertValue = upperAlertValue
        self.lowerAlertValue = lowerAlertValue
    }
}
