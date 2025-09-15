import UIKit
import DGCharts
import Foundation
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService

class TagChartsCollectionViewCell: UICollectionViewCell {

    private lazy var chartView = TagChartsView()
    private var settings: RuuviLocalSettings!
    private var measurementService: RuuviServiceMeasurement!
    private var measurementType: MeasurementType = .temperature

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(chartView)
        chartView.fillSuperview()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        chartView.underlyingView.data?.clearValues()
        chartView.underlyingView.data = nil
    }

    func populateChartView(
        from data: TagChartViewData,
        settings: RuuviLocalSettings,
        measurementService: RuuviServiceMeasurement,
        measurementType: MeasurementType,
        showAlertRangeInGraph: Bool
    ) {
        self.settings = settings
        self.measurementService = measurementService
        self.measurementType = measurementType

        var unit: String = ""
        switch measurementType {
        case .temperature:
            unit = settings.temperatureUnit.symbol
        case .humidity:
            unit = settings.humidityUnit.symbol
        case .pressure:
            unit = settings.pressureUnit.symbol
        default:
            break
        }

        chartView.setChartLabel(
            type: data.chartType,
            measurementService: measurementService,
            unit: unit
        )
        chartView.underlyingView.data = data.chartData
        chartView.underlyingView.lowerAlertValue = data.lowerAlertValue
        chartView.underlyingView.upperAlertValue = data.upperAlertValue
        chartView.setSettings(settings: settings)
        chartView.localize()
        chartView.setYAxisLimit(min: data.chartData?.yMin ?? 0, max: data.chartData?.yMax ?? 0)
        chartView.setXAxisRenderer(showAll: settings.chartShowAll)
        chartView.setChartStatVisible(show: true)

        // Calculation of min/max depends on the chart
        // internal viewport state. Give it a chance to
        // redraw itself before calculation.
        // Fixes https://github.com/ruuvi/com.ruuvi.station.ios/issues/1758
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            sSelf.calculateMinMaxForChart(for: sSelf.chartView)
            if showAlertRangeInGraph {
                sSelf.calculateAlertFillIfNeeded(for: sSelf.chartView)
            }
        }
        calculateMinMaxForChart(for: chartView)
        if showAlertRangeInGraph {
            calculateAlertFillIfNeeded(for: chartView)
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func calculateAlertFillIfNeeded(for view: TagChartsView) {
        if let data = view.underlyingView.data,
           let dataSet = data.dataSets.first as? LineChartDataSet {

            let maxY = view.highestVisibleY
            let minY = view.lowestVisibleY

            let colorRegular = RuuviColor.graphFillColor.color
            let colorAlert = RuuviColor.graphAlertColor.color

            if let upperAlertValue = view.underlyingView.upperAlertValue,
               let lowerAlertValue = view.underlyingView.lowerAlertValue {
                let colorLocations: [CGFloat]
                let gradientColors: CFArray
                if lowerAlertValue <= minY && upperAlertValue >= maxY {
                    colorLocations = [
                        0,
                        1,
                    ]
                    gradientColors = [
                        colorRegular.cgColor,
                        colorRegular.cgColor,
                    ] as CFArray
                    if let gradient = CGGradient(
                        colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: gradientColors,
                        locations: colorLocations
                    ) {
                        dataSet.drawFilledEnabled = true
                        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
                    }
                } else if minY >= lowerAlertValue && minY >= upperAlertValue {
                    colorLocations = [
                        0,
                        1,
                    ]
                    gradientColors = [
                        colorAlert.cgColor,
                        colorAlert.cgColor,
                    ] as CFArray
                    if let gradient = CGGradient(
                        colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: gradientColors,
                        locations: colorLocations
                    ) {
                        dataSet.drawFilledEnabled = true
                        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
                    }
                } else if lowerAlertValue <= minY && upperAlertValue <= maxY {
                    let alertRelativeY = (upperAlertValue - minY) / (maxY - minY)
                    colorLocations = [
                        0,
                        alertRelativeY,
                        alertRelativeY + .leastNonzeroMagnitude,
                        1,
                    ]
                    gradientColors = [
                        colorRegular.cgColor,
                        colorRegular.cgColor,
                        colorAlert.cgColor,
                        colorAlert.cgColor,
                    ] as CFArray
                    if let gradient = CGGradient(
                        colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: gradientColors,
                        locations: colorLocations
                    ) {
                        dataSet.drawFilledEnabled = true
                        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
                    }
                } else if lowerAlertValue >= minY && upperAlertValue >= maxY {
                    let alertRelativeY = (lowerAlertValue - minY) / (maxY - minY)
                    colorLocations = [
                        0,
                        alertRelativeY,
                        alertRelativeY + .leastNonzeroMagnitude,
                        1,
                    ]
                    gradientColors = [
                        colorAlert.cgColor,
                        colorAlert.cgColor,
                        colorRegular.cgColor,
                        colorRegular.cgColor,
                    ] as CFArray
                    if let gradient = CGGradient(
                        colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: gradientColors,
                        locations: colorLocations
                    ) {
                        dataSet.drawFilledEnabled = true
                        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
                    }
                } else if lowerAlertValue >= minY && upperAlertValue <= maxY {
                    let lowerAlertRelativeY = (lowerAlertValue - minY) / (maxY - minY)
                    let upperAlertRelativeY = (upperAlertValue - minY) / (maxY - minY)
                    colorLocations = [
                        0,
                        lowerAlertRelativeY,
                        lowerAlertRelativeY + .leastNonzeroMagnitude,
                        upperAlertRelativeY,
                        upperAlertRelativeY + .leastNonzeroMagnitude,
                        1,
                    ]
                    gradientColors = [
                        colorAlert.cgColor,
                        colorAlert.cgColor,
                        colorRegular.cgColor,
                        colorRegular.cgColor,
                        colorAlert.cgColor,
                        colorAlert.cgColor,
                    ] as CFArray

                    if let gradient = CGGradient(
                        colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: gradientColors,
                        locations: colorLocations
                    ) {
                        dataSet.drawFilledEnabled = true
                        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
                    }
                }
            }
        }
    }

    private func calculateMinMaxForChart(for view: TagChartsView) {
        if let data = view.underlyingView.data,
           let dataSet = data.dataSets.first as? LineChartDataSet {
            let lowestVisibleX = view.underlyingView.lowestVisibleX
            let highestVisibleX = view.underlyingView.highestVisibleX

            var minVisibleYValue = Double.greatestFiniteMagnitude
            var maxVisibleYValue = -Double.greatestFiniteMagnitude

            dataSet.entries.forEach { entry in
                if entry.x >= lowestVisibleX, entry.x <= highestVisibleX {
                    minVisibleYValue = min(minVisibleYValue, entry.y)
                    maxVisibleYValue = max(maxVisibleYValue, entry.y)
                }
            }

            let averageYValue = calculateVisibleAverage(
                chartView: view.underlyingView,
                dataSet: dataSet
            )

            view.setChartStat(
                min: minVisibleYValue,
                max: maxVisibleYValue,
                avg: averageYValue,
                type: self.measurementType,
                measurementService: measurementService
            )
        }
    }

    /**
     Calculate the average value of visible data points on a `LineChartView`.
     This function computes the average by considering the area under the curve
     formed by the visible data points and then divides it by the width of the visible x-range.
     The area under the curve is approximated using the trapezoidal rule.

     - Parameters:
     - chartView: The `LineChartView` instance whose visible range's average needs to be calculated.
     - dataSet: The `LineChartDataSet` containing data points to be considered.

     - Returns: The average value of visible data points.

     - Note:
     The function uses the trapezoidal rule for approximation. The formula for the trapezoidal rule is:
     A = (b - a) * (f(a) + f(b)) / 2
     Where:
     - A is the area of the trapezium.
     - a and b are the x-coordinates of the two data points.
     - f(a) and f(b) are the y-coordinates (or values) of the two data points.

     The average is then computed as the total area divided by the width of the visible x-range.
     */
    private func calculateVisibleAverage(chartView: LineChartView, dataSet: LineChartDataSet) -> Double {
        // Get the x-values defining the visible range of the chart.
        let lowestVisibleX = chartView.lowestVisibleX
        let highestVisibleX = chartView.highestVisibleX

        // Filter out the entries that lie within the visible range.
        let visibleEntries = dataSet.entries.filter { $0.x >= lowestVisibleX && $0.x <= highestVisibleX }

        // If there are no visible entries, return an average of 0.
        guard !visibleEntries.isEmpty else { return 0.0 }

        var totalArea = 0.0
        // Compute the area under the curve for each pair of consecutive points.
        for i in 1 ..< visibleEntries.count {
            let x1 = visibleEntries[i - 1].x
            let y1 = visibleEntries[i - 1].y
            let x2 = visibleEntries[i].x
            let y2 = visibleEntries[i].y

            // Calculate the area of the trapezium formed by two consecutive data points.
            let area = (x2 - x1) * (y1 + y2) / 2.0
            totalArea += area
        }

        // Calculate the width of the visible x-range.
        let timeSpan = visibleEntries.last!.x - visibleEntries.first!.x

        // If all visible data points have the same x-value, simply return the average of their y-values.
        if timeSpan == 0 {
            return visibleEntries.map(\.y).reduce(0, +) / Double(visibleEntries.count)
        }

        // Compute the average using the trapezoidal rule.
        return totalArea / timeSpan
    }
}
