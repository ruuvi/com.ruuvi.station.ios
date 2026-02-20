import CoreGraphics
import DGCharts
import Foundation
import RuuviLocalization
import UIKit

enum RuuviGraphDataSetFactory {

    // MARK: - Constants
    private enum Constants {
        static let lineWidth: CGFloat = 1
        static let circleRadius: CGFloat = 0.8
        static let fillAlpha: CGFloat = 0.3
        static let highlightLineDashLengths: [CGFloat] = [2, 1, 0]
        static let highlightLineWidth: CGFloat = 1
        static let maximumGapBetweenPoints: Double = 3600
        static let gapCircleRadius: CGFloat = 0.5
        static let gapLineWidth: CGFloat = 1
    }

    // MARK: - Chart Style Configuration
    struct ChartStyle {
        let fillEnabled: Bool
        let fillColor: UIColor
        let showGapBetweenPoints: Bool
        let drawAlertRangeThresholdLine: Bool

        static let full = ChartStyle(
            fillEnabled: true,
            fillColor: RuuviColor.graphFillColor.color,
            showGapBetweenPoints: true,
            drawAlertRangeThresholdLine: true
        )

        static let popup = ChartStyle(
            fillEnabled: false,
            fillColor: .clear,
            showGapBetweenPoints: true,
            drawAlertRangeThresholdLine: false
        )
    }

    // MARK: - Public Methods
    static func createDataSet(
        entries: [ChartDataEntry] = [],
        upperAlertValue: Double? = nil,
        lowerAlertValue: Double? = nil,
        showAlertRangeInGraph: Bool,
        style: ChartStyle = .full
    ) -> LineChartDataSet {
        let dataSet = createBaseDataSet(entries: entries, style: style)

        if showAlertRangeInGraph {
            configureAlertRange(
                for: dataSet,
                upperLimit: upperAlertValue,
                lowerLimit: lowerAlertValue
            )
        }

        return dataSet
    }

    // MARK: - Convenience Methods
    static func newDataSet(
        upperAlertValue: Double? = nil,
        entries: [ChartDataEntry] = [],
        lowerAlertValue: Double? = nil,
        showAlertRangeInGraph: Bool
    ) -> LineChartDataSet {
        return createDataSet(
            entries: entries,
            upperAlertValue: upperAlertValue,
            lowerAlertValue: lowerAlertValue,
            showAlertRangeInGraph: showAlertRangeInGraph,
            style: .full
        )
    }

    static func simpleGraphDataSet(
        upperAlertValue: Double? = nil,
        entries: [ChartDataEntry] = [],
        lowerAlertValue: Double? = nil,
        showAlertRangeInGraph: Bool
    ) -> LineChartDataSet {
        return createDataSet(
            entries: entries,
            upperAlertValue: upperAlertValue,
            lowerAlertValue: lowerAlertValue,
            showAlertRangeInGraph: showAlertRangeInGraph,
            style: .popup
        )
    }

    static func isFirstDataPointWithin36Hours(
        from entries: [ChartDataEntry]?
    ) -> Bool {
        guard let entries = entries,
              let earliest = entries.min(by: { $0.x < $1.x }) else {
            return false
        }

        let now = Date().timeIntervalSince1970
        let hours = max(0, (now - earliest.x) / 3600.0)
        return hours >= 36
    }

    static func isFirstDataPointWithin36Hours(
        from chartData: ChartData?
    ) -> Bool {
        guard let chartData = chartData else { return false }
        let allEntries: [ChartDataEntry] = chartData.dataSets.flatMap { dataSet in
            (0..<dataSet.entryCount).compactMap { dataSet.entryForIndex($0) }
        }
        return isFirstDataPointWithin36Hours(from: allEntries)
    }
}

// MARK: - Private Helper Methods
private extension RuuviGraphDataSetFactory {

    static func createBaseDataSet(
        entries: [ChartDataEntry],
        style: ChartStyle
    ) -> LineChartDataSet {
        let lineChartDataSet = LineChartDataSet(entries: entries)

        // Basic line configuration
        lineChartDataSet.axisDependency = .left
        lineChartDataSet.setColor(RuuviColor.graphLineColor.color)
        lineChartDataSet.lineWidth = Constants.lineWidth

        // Circle configuration
        lineChartDataSet.drawCirclesEnabled = false
        lineChartDataSet.circleRadius = Constants.circleRadius
        lineChartDataSet.drawCircleHoleEnabled = false

        // Fill configuration
        lineChartDataSet.drawFilledEnabled = style.fillEnabled
        lineChartDataSet.fillAlpha = Constants.fillAlpha
        lineChartDataSet.fillColor = style.fillColor

        // Highlight configuration
        lineChartDataSet.highlightEnabled = true
        lineChartDataSet.highlightColor = RuuviColor.graphFillColor.color
        lineChartDataSet.highlightLineDashLengths = Constants.highlightLineDashLengths
        lineChartDataSet.highlightLineWidth = Constants.highlightLineWidth

        // Gap configuration
        lineChartDataSet.maximumGapBetweenPoints = Constants.maximumGapBetweenPoints
        lineChartDataSet.gapCircleRadius = Constants.gapCircleRadius
        lineChartDataSet.gapLineWidth = Constants.gapLineWidth

        // Style-specific configuration
        lineChartDataSet.showGapBetweenPoints = style.showGapBetweenPoints
        lineChartDataSet.drawAlertRangeThresholdLine = style.drawAlertRangeThresholdLine

        // Values and alerts
        lineChartDataSet.drawValuesEnabled = false
        lineChartDataSet.hasAlertRange = false

        return lineChartDataSet
    }

    static func configureAlertRange(
        for dataSet: LineChartDataSet,
        upperLimit: Double?,
        lowerLimit: Double?
    ) {
        guard upperLimit != nil || lowerLimit != nil else { return }

        let alertColor = RuuviColor.graphAlertColor.color
        dataSet.alertColor = alertColor
        dataSet.hasAlertRange = true

        if let upperLimit = upperLimit {
            dataSet.upperAlertLimit = upperLimit
        }

        if let lowerLimit = lowerLimit {
            dataSet.lowerAlertLimit = lowerLimit
        }
    }
}
