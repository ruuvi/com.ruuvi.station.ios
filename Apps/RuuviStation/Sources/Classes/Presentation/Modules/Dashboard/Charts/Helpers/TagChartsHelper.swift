import CoreGraphics
import DGCharts
import Foundation
import RuuviLocalization
import UIKit

enum TagChartsHelper {
    static func newDataSet(
        upperAlertValue: Double?,
        entries: [ChartDataEntry] = [],
        lowerAlertValue: Double?
    ) -> LineChartDataSet {
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

        let color = RuuviColor.graphFillColor.color
        let alertColor = RuuviColor.graphAlertColor.color

        if let upperAlertValue, let lowerAlertValue {
            lineChartDataSet.isDrawLineWithGradientEnabled = true
            lineChartDataSet.colors = [alertColor, alertColor, color, color, alertColor, alertColor]
            lineChartDataSet.gradientPositions = [
                -.infinity,
                lowerAlertValue,
                lowerAlertValue + .leastNonzeroMagnitude,
                upperAlertValue,
                upperAlertValue + .leastNonzeroMagnitude,
                .infinity,
            ]
        } else if let upperAlertValue {
            lineChartDataSet.isDrawLineWithGradientEnabled = true
            lineChartDataSet.colors = [color, color, alertColor, alertColor]
            lineChartDataSet.gradientPositions = [
                -.infinity,
                upperAlertValue,
                upperAlertValue + .leastNonzeroMagnitude,
                .infinity,
            ]
        } else if let lowerAlertValue {
            lineChartDataSet.isDrawLineWithGradientEnabled = true
            lineChartDataSet.colors = [alertColor, alertColor, color, color]
            lineChartDataSet.gradientPositions = [
                -.infinity,
                 lowerAlertValue,
                 lowerAlertValue + .leastNonzeroMagnitude,
                .infinity,
            ]
        }

        return lineChartDataSet
    }
}
