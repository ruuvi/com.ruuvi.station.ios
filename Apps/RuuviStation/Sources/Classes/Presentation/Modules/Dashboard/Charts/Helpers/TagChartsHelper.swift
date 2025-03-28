import CoreGraphics
import DGCharts
import Foundation
import RuuviLocalization
import UIKit

enum TagChartsHelper {

    // swiftlint:disable:next function_body_length
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

        if showAlertRangeInGraph {
            let lineColor = RuuviColor.graphLineColor.color
            let alertColor = RuuviColor.graphAlertColor.color

            if let upperAlertValue, let lowerAlertValue {
                lineChartDataSet.isDrawLineWithGradientEnabled = true
                lineChartDataSet.colors = [alertColor, alertColor, lineColor, lineColor, alertColor, alertColor]
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
                lineChartDataSet.colors = [lineColor, lineColor, alertColor, alertColor]
                lineChartDataSet.gradientPositions = [
                    -.infinity,
                     upperAlertValue,
                     upperAlertValue + .leastNonzeroMagnitude,
                     .infinity,
                ]
            } else if let lowerAlertValue {
                lineChartDataSet.isDrawLineWithGradientEnabled = true
                lineChartDataSet.colors = [alertColor, alertColor, lineColor, lineColor]
                lineChartDataSet.gradientPositions = [
                    -.infinity,
                     lowerAlertValue,
                     lowerAlertValue + .leastNonzeroMagnitude,
                     .infinity,
                ]
            }
        }

        return lineChartDataSet
    }
}
