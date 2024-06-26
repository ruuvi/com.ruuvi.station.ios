import DGCharts
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
import UIKit

// swiftlint:disable file_length

protocol TagChartsViewDelegate: NSObjectProtocol {
    func chartDidTranslate(_ chartView: TagChartsView)
    func chartValueDidSelect(
        _ chartView: TagChartsView,
        entry: ChartDataEntry,
        highlight: Highlight
    )
    func chartValueDidDeselect(_ chartView: TagChartsView)
}

class TagChartsView: LineChartView {
    weak var chartDelegate: TagChartsViewDelegate?
    var lowerAlertValue: Double?
    var upperAlertValue: Double?
    private var settings: RuuviLocalSettings!
    private var chartName: String = ""

    private lazy var chartNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.Muli(.regular, size: UIDevice.isTablet() ? 12 : 10)
        return label
    }()

    private lazy var chartMinMaxAvgLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.Muli(.regular, size: UIDevice.isTablet() ? 12 : 10)
        return label
    }()

    private lazy var markerView = TagChartsMarkerView()

    // MARK: - LifeCycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        addSubviews()
        configure()
        localize()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    private func addSubviews() {
        addSubview(chartNameLabel)
        chartNameLabel.anchor(
            top: nil,
            leading: nil,
            bottom: bottomAnchor,
            trailing: trailingAnchor,
            padding: .init(
                top: 0,
                left: 0,
                bottom: UIDevice.isTablet() ? 42 : 28,
                right: 16
            )
        )

        addSubview(chartMinMaxAvgLabel)
        chartMinMaxAvgLabel.anchor(
            top: nil,
            leading: nil,
            bottom: chartNameLabel.topAnchor,
            trailing: trailingAnchor,
            padding: .init(
                top: 0, left: 0, bottom: 4, right: 16
            )
        )
        chartMinMaxAvgLabel.isHidden = true
    }

    // MARK: - Private

    private func configure() {
        chartDescription.enabled = false
        dragEnabled = true
        setScaleEnabled(true)
        pinchZoomEnabled = false
        highlightPerDragEnabled = false
        backgroundColor = .clear
        legend.enabled = false

        xAxis.labelPosition = .bottom
        xAxis.labelFont = .Muli(.regular, size: UIDevice.isTablet() ? 12 : 10)
        xAxis.labelTextColor = UIColor.white
        xAxis.drawAxisLineEnabled = true
        xAxis.drawGridLinesEnabled = true
        xAxis.centerAxisLabelsEnabled = false
        xAxis.granularity = 1
        xAxis.granularityEnabled = true
        viewPortHandler.setMaximumScaleX(5000)
        viewPortHandler.setMaximumScaleY(30)
        xAxis.setLabelCount(5, force: false)
        xAxis.valueFormatter = XAxisValueFormatter()
        xAxis.forceLabelsEnabled = true

        leftAxis.labelPosition = .outsideChart
        leftAxis.labelAlignment = .right
        leftAxis.labelFont = .Muli(.regular, size: UIDevice.isTablet() ? 12 : 10)
        leftAxis.setLabelCount(6, force: false)
        leftAxis.drawGridLinesEnabled = true
        leftAxis.labelTextColor = UIColor.white
        leftAxis.minWidth = UIDevice.isTablet() ? 70.0 : 44.0
        leftAxis.maxWidth = UIDevice.isTablet() ? 70.0 : 44.0
        leftAxis.xOffset = 6
        leftAxis.granularityEnabled = true
        leftAxis.granularity = 1
        leftAxis.spaceBottom = 0.2
        leftAxis.drawZeroLineEnabled = true
        leftAxis.forceLabelsEnabled = true

        rightAxis.enabled = false

        legend.form = .line
        noDataTextColor = UIColor.clear
        scaleXEnabled = true
        scaleYEnabled = true

        drawMarkers = true
        markerView.chartView = self
        marker = markerView
        setExtraOffsets(left: 2, top: 4, right: 0, bottom: 2)
    }

    private func reloadData() {
        data?.notifyDataChanged()
        notifyDataSetChanged()
    }
}

extension TagChartsView: ChartViewDelegate {
    func chartTranslated(
        _: ChartViewBase,
        dX _: CGFloat,
        dY _: CGFloat
    ) {
        chartDelegate?.chartDidTranslate(self)
    }

    func chartScaled(
        _: ChartViewBase,
        scaleX _: CGFloat,
        scaleY _: CGFloat
    ) {
        chartDelegate?.chartDidTranslate(self)
    }

    func chartValueSelected(
        _: ChartViewBase,
        entry: ChartDataEntry,
        highlight: Highlight
    ) {
        chartDelegate?.chartValueDidSelect(
            self,
            entry: entry,
            highlight: highlight
        )
    }

    func chartValueNothingSelected(_: ChartViewBase) {
        chartDelegate?.chartValueDidDeselect(self)
    }
}

extension TagChartsView {
    func localize() {
        xAxis.valueFormatter = XAxisValueFormatter()
        leftAxis.valueFormatter = YAxisValueFormatter()
    }

    func clearChartData() {
        clearValues()
        resetCustomAxisMinMax()
        resetZoom()
        reloadData()
        fitScreen()
    }

    func setYAxisLimit(min: Double, max: Double) {
        leftAxis.axisMinimum = min - 1
        leftAxis.axisMaximum = max + 1
        leftYAxisRenderer = CustomYAxisRenderer(
            viewPortHandler: viewPortHandler,
            axis: leftAxis,
            transformer: getTransformer(forAxis: .left)
        )

        // Ensure entries are calculated
        leftAxis.calculate(min: leftAxis.axisMinimum, max: leftAxis.axisMaximum)

        // Set these values if entries greater than 0, otherwise the implementation of
        // YAxisRenderer within Charts lib could lead to crash in looping though the range as
        // the range of labels is modified by these below booleans and could end up in a state
        // where starting range could be greater than the ending range.
        let entriesNotZero = leftAxis.entries.count > 0
        leftAxis.drawTopYLabelEntryEnabled = !entriesNotZero
        leftAxis.drawBottomYLabelEntryEnabled = !entriesNotZero
    }
    func setXAxisRenderer() {
        let axisRenderer = CustomXAxisRenderer(
            from: 0,
            viewPortHandler: viewPortHandler,
            axis: xAxis,
            transformer: getTransformer(forAxis: .left)
        )
        xAxisRenderer = axisRenderer

        if !settings.chartShowAll {
            let from = Calendar.autoupdatingCurrent.date(
                byAdding: .hour,
                value: -settings.chartDurationHours,
                to: Date()
            ) ?? Date.distantFuture
            xAxis.axisMinimum = from.timeIntervalSince1970
            xAxis.axisMaximum = Date().timeIntervalSince1970
        }
    }

    func resetCustomAxisMinMax() {
        xAxis.resetCustomAxisMin()
        xAxis.resetCustomAxisMax()
    }

    func setSettings(settings: RuuviLocalSettings) {
        self.settings = settings
    }

    // MARK: - UpdateUI

    func updateDataSet(
        with newData: [ChartDataEntry],
        isFirstEntry: Bool,
        showAlertRangeInGraph: Bool
    ) {
        if isFirstEntry {
            let emptyDataSet = LineChartData(
                dataSet: TagChartsHelper.newDataSet(
                    upperAlertValue: upperAlertValue,
                    lowerAlertValue: lowerAlertValue,
                    showAlertRangeInGraph: showAlertRangeInGraph
                )
            )
            data = emptyDataSet
        }

        for point in newData {
            data?.appendEntry(point, toDataSet: 0)
            setYAxisLimit(min: data?.yMin ?? 0, max: data?.yMax ?? 0)
        }
        reloadData()
    }

    func updateLatest(
        with entry: ChartDataEntry?,
        type: MeasurementType,
        measurementService: RuuviServiceMeasurement,
        unit: String
    ) {
        guard let entry else { return }
        switch type {
        case .temperature:
            let tempValue = measurementService.stringWithoutSign(temperature: entry.y)
            chartNameLabel.text = chartName + " (\(tempValue) \(unit))"
        case .humidity:
            let humidityValue = measurementService.stringWithoutSign(humidity: entry.y)
            chartNameLabel.text = chartName + " (\(humidityValue) \(unit))"
        case .pressure:
            let pressureValue = measurementService.stringWithoutSign(pressure: entry.y)
            chartNameLabel.text = chartName + " (\(pressureValue) \(unit))"
        default: break
        }
    }

    func setChartLabel(
        with name: String,
        type: MeasurementType,
        measurementService: RuuviServiceMeasurement,
        unit: String
    ) {
        chartName = name
        chartNameLabel.text = name
        if let marker = marker as? TagChartsMarkerView {
            marker.initialise(
                with: unit,
                type: type,
                measurementService: measurementService,
                parentFrame: frame
            )
        }
    }

    func hideChartNameLabel(hide: Bool) {
        chartNameLabel.alpha = hide ? 0 : 1
    }

    func setChartStat(
        min: Double,
        max: Double,
        avg: Double,
        type: MeasurementType,
        measurementService: RuuviServiceMeasurement
    ) {
        let measurement = createMeasurementStrings(
            type: type,
            min: min,
            max: max,
            avg: avg,
            measurementService: measurementService
        )
        chartMinMaxAvgLabel.text = measurement
    }

    func clearChartStat() {
        chartMinMaxAvgLabel.text = nil
    }

    func setChartStatVisible(show: Bool) {
        chartMinMaxAvgLabel.isHidden = !show
    }

    /// The lowest y-index (value on the y-axis) that is still visible on he chart.
    var lowestVisibleY: Double {
        var pt = CGPoint(
            x: viewPortHandler.contentLeft,
            y: viewPortHandler.contentBottom
        )

        getTransformer(forAxis: .left).pixelToValues(&pt)

        return max(leftAxis.axisMinimum, Double(pt.y))
    }

    /// The highest y-index (value on the y-axis) that is still visible on the chart.
    var highestVisibleY: Double {
        var pt = CGPoint(
            x: viewPortHandler.contentLeft,
            y: viewPortHandler.contentTop
        )

        getTransformer(forAxis: .left).pixelToValues(&pt)

        return min(leftAxis.axisMaximum, Double(pt.y))
    }
}

extension TagChartsView {

    private func createMeasurementStrings(
        type: MeasurementType,
        min: Double?,
        max: Double?,
        avg: Double?,
        measurementService: RuuviServiceMeasurement
    ) -> String {
        let minValue = formattedMeasurementString(
            for: type,
            value: min,
            measurementService: measurementService
        )

        let maxValue = formattedMeasurementString(
            for: type,
            value: max,
            measurementService: measurementService
        )

        let avgValue = formattedMeasurementString(
            for: type,
            value: avg,
            measurementService: measurementService
        )

        return RuuviLocalization.chartMinMaxAvg(minValue, maxValue, avgValue)
    }

    private func formattedMeasurementString(
        for type: MeasurementType,
        value: Double?,
        measurementService: RuuviServiceMeasurement
    ) -> String {
        switch type {
        case .temperature:
            return measurementService.stringWithoutSign(
                temperature: value
            )
        case .humidity:
            return measurementService.stringWithoutSign(
                humidity: value
            )
        case .pressure:
            return measurementService.stringWithoutSign(
                pressure: value
            )
        default:
            return ""
        }
    }
}

// swiftlint:enable file_length
