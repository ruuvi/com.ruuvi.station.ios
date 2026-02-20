// swiftlint:disable file_length

import DGCharts
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
import UIKit

enum CardsGraphSource {
    case cards
    case mesurementDetails
}

protocol CardsGraphInternalViewDelegate: NSObjectProtocol {
    func chartDidTranslate(_ chartView: CardsGraphInternalView)
    func chartValueDidSelect(
        _ chartView: CardsGraphInternalView,
        entry: ChartDataEntry,
        highlight: Highlight
    )
    func chartValueDidDeselect(_ chartView: CardsGraphInternalView)
    func chartDidSingleTap(_ chartView: CardsGraphInternalView, location: CGPoint)
    func chartMarkerInteractionDidBegin(_ chartView: CardsGraphInternalView)
    func chartMarkerInteractionDidEnd(_ chartView: CardsGraphInternalView)
}

class CardsGraphInternalView: LineChartView {
    weak var chartDelegate: CardsGraphInternalViewDelegate?

    var lowerAlertValue: Double?
    var upperAlertValue: Double?
    var graphType: MeasurementType = .temperature

    // MARK: - Private
    private lazy var markerView = CardsGraphMarkerView()
    private var settings: RuuviLocalSettings!
    private var source: CardsGraphSource = .cards
    private var markerInteractionActive = false
    private var dragWasEnabled: Bool?
    private var pinnedHighlight: Highlight?
    private var currentHighlight: Highlight?
    private var suppressNextDeselectCallback = false
    private var isLongPressActive = false
    private lazy var longPressRecognizer = UILongPressGestureRecognizer(
        target: self,
        action: #selector(handleLongPress(_:))
    )
    private lazy var tapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(_:))
        )
        recognizer.cancelsTouchesInView = false
        return recognizer
    }()

    // MARK: - LifeCycle
    init(source: CardsGraphSource, graphType: MeasurementType) {
        self.source = source
        self.graphType = graphType
        super.init(frame: .zero)
        delegate = self
        configure()
        localize()
    }

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
        highlightPerTapEnabled = false
        backgroundColor = .clear
        legend.enabled = false

        xAxis.labelPosition = .bottom
        xAxis.labelFont = UIFont.ruuviCaption2()
        xAxis.labelTextColor =
            (source == .mesurementDetails) ? RuuviColor.dashboardIndicator.color : UIColor.white
        xAxis.drawAxisLineEnabled = true
        xAxis.drawGridLinesEnabled = true
        xAxis.gridColor = xAxis.gridColor.withAlphaComponent(0.4)
        xAxis.centerAxisLabelsEnabled = false
        xAxis.setLabelCount(5, force: false)
        xAxis.valueFormatter = XAxisValueFormatter()

        leftAxis.labelPosition = .outsideChart
        leftAxis.labelAlignment = .right
        leftAxis.labelFont = UIFont.ruuviCaption2()
        leftAxis.setLabelCount(6, force: false)
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridColor = leftAxis.gridColor.withAlphaComponent(0.4)
        leftAxis.labelTextColor =
            (source == .mesurementDetails) ? RuuviColor.dashboardIndicator.color : UIColor.white
        leftAxis.minWidth = UIDevice.isTablet() ? 54.0 : 44.0
        leftAxis.maxWidth = UIDevice.isTablet() ? 54.0 : 44.0
        leftAxis.xOffset = 6
        leftAxis.granularityEnabled = true
        leftAxis.granularity = 1
        leftAxis.spaceBottom = 0.2

        rightAxis.enabled = false

        legend.form = .line
        scaleXEnabled = true
        scaleYEnabled = true
        viewPortHandler.setMaximumScaleX(5000)
        viewPortHandler.setMaximumScaleY(30)
        noDataTextColor = UIColor.clear

        drawMarkers = true
        markerView.chartView = self
        marker = markerView
        setExtraOffsets(left: 2, top: 4, right: 20, bottom: 2)

        tapRecognizer.require(toFail: longPressRecognizer)
        addGestureRecognizer(tapRecognizer)
        addGestureRecognizer(longPressRecognizer)
    }

    private func reloadData() {
        data?.notifyDataChanged()
        notifyDataSetChanged()
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: self)
        switch gesture.state {
        case .began:
            pinnedHighlight = nil
            guard highlightTouchPoint(
                point,
                pin: true,
                notifyDelegate: true
            ) != nil else { return }
            isLongPressActive = true
            beginMarkerInteractionIfNeeded()
        case .changed:
            guard isLongPressActive else { return }
            highlightTouchPoint(point, pin: true, notifyDelegate: true)
        case .ended, .cancelled, .failed:
            isLongPressActive = false
            endMarkerInteraction(clearHighlight: false)
        default:
            break
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        if currentHighlight != nil,
           let markerView = marker as? CardsGraphMarkerView {
            let location = gesture.location(in: self)
            if markerView.lastDrawnRect.contains(location) {
                clearPinnedHighlight()
                return
            }
        }
        chartDelegate?.chartDidSingleTap(
            self,
            location: gesture.location(in: self)
        )
    }

    private func beginMarkerInteractionIfNeeded() {
        guard !markerInteractionActive else { return }
        markerInteractionActive = true
        dragWasEnabled = dragEnabled
        dragEnabled = false
        chartDelegate?.chartMarkerInteractionDidBegin(self)
    }

    private func endMarkerInteraction(clearHighlight: Bool) {
        if markerInteractionActive {
            markerInteractionActive = false
            chartDelegate?.chartMarkerInteractionDidEnd(self)
        }

        if let dragWasEnabled {
            dragEnabled = dragWasEnabled
        }

        if clearHighlight {
            clearPinnedHighlight()
        }

        dragWasEnabled = nil
    }

    private func clearPinnedHighlight() {
        pinnedHighlight = nil
        clearHighlight(notifyDelegate: true)
    }

    private func clearHighlight(notifyDelegate: Bool) {
        currentHighlight = nil
        suppressNextDeselectCallback = true
        highlightValue(nil)
        if notifyDelegate {
            chartDelegate?.chartValueDidDeselect(self)
        }
    }

    @discardableResult
    private func highlightTouchPoint(
        _ point: CGPoint,
        pin: Bool,
        notifyDelegate: Bool
    ) -> Highlight? {
        guard let highlight = getHighlightByTouchPoint(point) else { return nil }
        if pin {
            pinnedHighlight = highlight
        }
        applyHighlight(highlight, notifyDelegate: notifyDelegate)
        return highlight
    }

    private func applyHighlight(_ highlight: Highlight, notifyDelegate: Bool) {
        currentHighlight = highlight
        highlightValue(highlight)
        guard notifyDelegate,
              let entry = entry(for: highlight) else {
            return
        }
        chartDelegate?.chartValueDidSelect(
            self,
            entry: entry,
            highlight: highlight
        )
    }

    private func entry(for highlight: Highlight) -> ChartDataEntry? {
        guard let data else { return nil }
        let dataSetCount = data.dataSets.count
        guard dataSetCount > 0 else { return nil }
        let resolvedIndex = min(max(0, highlight.dataSetIndex), dataSetCount - 1)
        let dataSet = data.dataSets[resolvedIndex]
        return dataSet.entryForXValue(highlight.x, closestToY: highlight.y)
    }
}

extension CardsGraphInternalView: ChartViewDelegate {
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
        if let pinnedHighlight {
            suppressNextDeselectCallback = false
            applyHighlight(pinnedHighlight, notifyDelegate: false)
            return
        }
        if suppressNextDeselectCallback {
            suppressNextDeselectCallback = false
            return
        }
        currentHighlight = nil
        chartDelegate?.chartValueDidDeselect(self)
    }
}

extension CardsGraphInternalView {
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
        if source == .mesurementDetails && graphType == .aqi {
            leftAxis.axisMinimum = 0
            leftAxis.axisMaximum = 100
            leftYAxisRenderer = AQIYAxisRenderer(
                viewPortHandler: viewPortHandler,
                axis: leftAxis,
                transformer: getTransformer(forAxis: .left)
            )
        } else {
            leftAxis.axisMinimum = min - 1
            leftAxis.axisMaximum = max + 1
            leftYAxisRenderer = CustomYAxisRenderer(
                viewPortHandler: viewPortHandler,
                axis: leftAxis,
                transformer: getTransformer(forAxis: .left)
            )
        }

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

    func setXAxisRenderer(
        showAll: Bool,
        timelineRange: ClosedRange<Double>? = nil
    ) {
        let axisRenderer = CustomXAxisRenderer(
            from: 0,
            viewPortHandler: viewPortHandler,
            axis: xAxis,
            transformer: getTransformer(forAxis: .left)
        )
        xAxisRenderer = axisRenderer

        if showAll {
            if let timelineRange {
                applyXAxisRange(
                    min: timelineRange.lowerBound,
                    max: timelineRange.upperBound
                )
            } else if let dataTimelineRange = resolveDataTimelineRange() {
                applyXAxisRange(
                    min: dataTimelineRange.lowerBound,
                    max: dataTimelineRange.upperBound
                )
            } else {
                resetCustomAxisMinMax()
            }
            return
        } else {
            let from = Calendar.autoupdatingCurrent.date(
                byAdding: .hour,
                value: -settings.chartDurationHours,
                to: Date()
            ) ?? Date.distantFuture
            xAxis.axisMinimum = from.timeIntervalSince1970
            xAxis.axisMaximum = Date().timeIntervalSince1970
        }
    }

    private func applyXAxisRange(min: Double, max: Double) {
        guard min.isFinite, max.isFinite else {
            return
        }
        xAxis.axisMinimum = min
        xAxis.axisMaximum = max > min ? max : min + 1
    }

    private func resolveDataTimelineRange() -> ClosedRange<Double>? {
        guard let dataSet = data?.dataSets.first as? LineChartDataSet,
              !dataSet.entries.isEmpty else {
            return nil
        }

        let xValues = dataSet.entries.map(\.x)
        guard let minX = xValues.min(),
              let maxX = xValues.max(),
              minX.isFinite,
              maxX.isFinite else {
            return nil
        }

        return minX...maxX
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
        firstEntry: RuuviMeasurement?,
        showAlertRangeInGraph: Bool
    ) {
        if isFirstEntry {
            let emptyDataSet = LineChartData(
                dataSet: RuuviGraphDataSetFactory.newDataSet(
                    upperAlertValue: upperAlertValue,
                    lowerAlertValue: lowerAlertValue,
                    showAlertRangeInGraph: showAlertRangeInGraph
                )
            )
            data = emptyDataSet
        }

        if highestVisibleX >= data?.xMax ?? 0 {
            for point in newData {
                if let set = data?.dataSets.first as? LineChartDataSet,
                    let index = data?.index(
                    of: set
                ) {
                    data?.appendEntry(point, toDataSet: index)
                    setYAxisLimit(min: data?.yMin ?? 0, max: data?.yMax ?? 0)
                }
            }

            if !settings.chartShowAll {
                let from = Calendar.autoupdatingCurrent.date(
                    byAdding: .hour,
                    value: -settings.chartDurationHours,
                    to: Date()
                ) ?? Date.distantFuture
                xAxis.axisMinimum = from.timeIntervalSince1970
                xAxis.axisMaximum = Date().timeIntervalSince1970
            }

            reloadData()
        }
    }

    func setMarker(
        with type: MeasurementType,
        measurementService: RuuviServiceMeasurement,
        unit: String
    ) {
        if let marker = marker as? CardsGraphMarkerView {
            marker.initialise(
                with: unit,
                type: type,
                measurementService: measurementService,
                parentFrame: frame
            )
        }
    }

    func highlightEntry(
        atX xValue: Double,
        closestToY yValue: Double,
        dataSetIndex: Int
    ) {
        guard let data else {
            clearHighlight(notifyDelegate: false)
            return
        }

        let dataSetCount = data.dataSets.count
        guard dataSetCount > 0 else {
            clearHighlight(notifyDelegate: false)
            return
        }

        let resolvedIndex = min(max(0, dataSetIndex), dataSetCount - 1)
        let dataSet = data.dataSets[resolvedIndex]
        guard let entry = dataSet.entryForXValue(xValue, closestToY: yValue) else {
            clearHighlight(notifyDelegate: false)
            return
        }

        let highlight = Highlight(
            x: entry.x,
            y: entry.y,
            dataSetIndex: resolvedIndex
        )
        applyHighlight(highlight, notifyDelegate: false)
    }

    func clearMarker() {
        pinnedHighlight = nil
        clearHighlight(notifyDelegate: false)
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

// swiftlint:enable file_length
