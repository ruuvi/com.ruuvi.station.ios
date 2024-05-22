import DGCharts
import Foundation
import RuuviLocalization

enum TagChartsHelper {
    static func newDataSet(entries: [ChartDataEntry] = []) -> LineChartDataSet {
        let lineChartDataSet = LineChartDataSet(entries: entries)
        lineChartDataSet.axisDependency = .left
        lineChartDataSet.setColor(RuuviColor.graphLineColor.color)
        lineChartDataSet.lineWidth = 1.5
        lineChartDataSet.drawCirclesEnabled = false
        lineChartDataSet.circleRadius = 0.8
        lineChartDataSet.drawValuesEnabled = false
        lineChartDataSet.fillAlpha = 1
        lineChartDataSet.fillColor = RuuviColor.graphFillColor.color
        lineChartDataSet.highlightColor = RuuviColor.graphFillColor.color
        lineChartDataSet.highlightLineDashLengths = [2, 1, 0]
        lineChartDataSet.highlightLineWidth = 1
        lineChartDataSet.drawCircleHoleEnabled = false
        lineChartDataSet.drawFilledEnabled = true
        lineChartDataSet.highlightEnabled = true
        return lineChartDataSet
    }
}
