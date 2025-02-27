import DGCharts
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
import UIKit

protocol TagChartsViewInternalDelegate: NSObjectProtocol {
    func chartDidTranslate(_ chartView: TagChartsViewInternal)
    func chartValueDidSelect(
        _ chartView: TagChartsViewInternal,
        entry: ChartDataEntry,
        highlight: Highlight
    )
    func chartValueDidDeselect(_ chartView: TagChartsViewInternal)
}

class TagChartsViewInternal: LineChartView {
    weak var chartDelegate: TagChartsViewInternalDelegate?

    var lowerAlertValue: Double?
    var upperAlertValue: Double?

    // MARK: - Private
    private lazy var markerView = TagChartsMarkerView()
    private var settings: RuuviLocalSettings!

    // MARK: - LifeCycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        configure()
        localize()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        xAxis.gridColor = xAxis.gridColor.withAlphaComponent(0.4)
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
        leftAxis.gridColor = leftAxis.gridColor.withAlphaComponent(0.4)
        leftAxis.labelTextColor = UIColor.white
        leftAxis.minWidth = UIDevice.isTablet() ? 70.0 : 44.0
        leftAxis.maxWidth = UIDevice.isTablet() ? 70.0 : 44.0
        leftAxis.xOffset = 6
        leftAxis.granularityEnabled = true
        leftAxis.granularity = 1
        leftAxis.spaceBottom = 0.2
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

extension TagChartsViewInternal: ChartViewDelegate {
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

extension TagChartsViewInternal {
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

    func setMarker(
        with type: MeasurementType,
        measurementService: RuuviServiceMeasurement,
        unit: String
    ) {
        if let marker = marker as? TagChartsMarkerView {
            marker.initialise(
                with: unit,
                type: type,
                measurementService: measurementService,
                parentFrame: frame
            )
        }
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
