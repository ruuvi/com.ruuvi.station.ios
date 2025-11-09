import Foundation
import DGCharts
import RuuviOntology

class RuuviGraphViewDataModel: NSObject {
    let variant: MeasurementDisplayVariant
    var chartType: MeasurementType { variant.type }
    var upperAlertValue: Double?
    var chartData: LineChartData?
    var lowerAlertValue: Double?

    init(
        upperAlertValue: Double?,
        variant: MeasurementDisplayVariant,
        chartData: LineChartData?,
        lowerAlertValue: Double?
    ) {
        self.upperAlertValue = upperAlertValue
        self.variant = variant
        self.chartData = chartData
        self.lowerAlertValue = lowerAlertValue
    }
}
