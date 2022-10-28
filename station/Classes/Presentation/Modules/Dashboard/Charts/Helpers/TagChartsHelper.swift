import Foundation
import Charts

struct TagChartsHelper {
    static func newDataSet(entries: [ChartDataEntry] = []) -> LineChartDataSet {
        let lineChartDataSet = LineChartDataSet(entries: entries)
        lineChartDataSet.axisDependency = .left
        lineChartDataSet.setColor(NSUIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1))
        lineChartDataSet.lineWidth = 1.5
        lineChartDataSet.drawCirclesEnabled = false
        lineChartDataSet.circleRadius = 0.8
        lineChartDataSet.drawValuesEnabled = false
        lineChartDataSet.fillAlpha = 0.26
        lineChartDataSet.fillColor = NSUIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
        lineChartDataSet.highlightColor = NSUIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        lineChartDataSet.drawCircleHoleEnabled = false
        lineChartDataSet.drawFilledEnabled = true
        lineChartDataSet.highlightEnabled = false
        return lineChartDataSet
    }
}
