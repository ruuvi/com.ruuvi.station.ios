import Foundation
import Charts

struct TagChartsHelper {
    static func newDataSet(entries: [ChartDataEntry] = []) -> LineChartDataSet {
        let lineChartDataSet = LineChartDataSet(entries: entries)
        lineChartDataSet.axisDependency = .left
        lineChartDataSet.setColor(RuuviColor.ruuviGraphLineColor ?? RuuviColor.fallbackGraphLineColor)
        lineChartDataSet.lineWidth = 1.5
        lineChartDataSet.drawCirclesEnabled = false
        lineChartDataSet.circleRadius = 0.8
        lineChartDataSet.drawValuesEnabled = false
        lineChartDataSet.fillAlpha = 1
        lineChartDataSet.fillColor = RuuviColor.ruuviGraphFillColor ?? RuuviColor.fallbackGraphFillColor
        lineChartDataSet.highlightColor = RuuviColor.ruuviGraphFillColor ?? RuuviColor.fallbackGraphFillColor
        lineChartDataSet.highlightLineDashLengths = [2, 1, 0]
        lineChartDataSet.highlightLineWidth = 1
        lineChartDataSet.drawCircleHoleEnabled = false
        lineChartDataSet.drawFilledEnabled = true
        lineChartDataSet.highlightEnabled = true
        return lineChartDataSet
    }
}
