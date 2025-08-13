import CoreGraphics
import DGCharts
import Foundation
import RuuviLocalization
import UIKit

enum TagChartsHelper {

    static func newDataSet(
        upperAlertValue: Double?,
        entries: [ChartDataEntry] = [],
        lowerAlertValue: Double?,
        showAlertRangeInGraph: Bool
    ) -> LineChartDataSet {
        let lineChartDataSet = LineChartDataSet(entries: entries)
        lineChartDataSet.axisDependency = .left
        lineChartDataSet.setColor(RuuviColor.graphLineColor.color)
        lineChartDataSet.lineWidth = 1
        lineChartDataSet.drawCirclesEnabled = false
        lineChartDataSet.circleRadius = 0.8
        lineChartDataSet.drawValuesEnabled = false
        lineChartDataSet.fillAlpha = 0.3
        lineChartDataSet.fillColor = RuuviColor.graphFillColor.color
        lineChartDataSet.highlightColor = RuuviColor.graphFillColor.color
        lineChartDataSet.highlightLineDashLengths = [2, 1, 0]
        lineChartDataSet.highlightLineWidth = 1
        lineChartDataSet.drawCircleHoleEnabled = false
        lineChartDataSet.drawFilledEnabled = true
        lineChartDataSet.highlightEnabled = true
        lineChartDataSet.maximumGapBetweenPoints = 3600
        lineChartDataSet.gapCircleRadius = 0.5
        lineChartDataSet.gapLineWidth = 1
        lineChartDataSet.hasAlertRange = false

        if showAlertRangeInGraph {
            let alertColor = RuuviColor.graphAlertColor.color
            if let upperAlertValue, let lowerAlertValue {
                lineChartDataSet.lowerAlertLimit = lowerAlertValue
                lineChartDataSet.upperAlertLimit = upperAlertValue
                lineChartDataSet.alertColor = alertColor
                lineChartDataSet.hasAlertRange = true
            } else if let upperAlertValue {
                lineChartDataSet.upperAlertLimit = upperAlertValue
                lineChartDataSet.alertColor = alertColor
                lineChartDataSet.hasAlertRange = true
            } else if let lowerAlertValue {
                lineChartDataSet.lowerAlertLimit = lowerAlertValue
                lineChartDataSet.alertColor = alertColor
                lineChartDataSet.hasAlertRange = true
            }
        }

        return lineChartDataSet
    }
}
