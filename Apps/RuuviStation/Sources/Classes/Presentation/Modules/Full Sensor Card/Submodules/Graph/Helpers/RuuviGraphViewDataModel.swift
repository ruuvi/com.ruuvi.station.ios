import Foundation
import DGCharts
import RuuviOntology

class RuuviGraphViewDataModel: NSObject {
    var chartType: MeasurementType
    var upperAlertValue: Double?
    var chartData: LineChartData?
    var lowerAlertValue: Double?

    init(
        upperAlertValue: Double?,
        chartType: MeasurementType,
        chartData: LineChartData?,
        lowerAlertValue: Double?
    ) {
        self.upperAlertValue = upperAlertValue
        self.chartType = chartType
        self.chartData = chartData
        self.lowerAlertValue = lowerAlertValue
    }
}
