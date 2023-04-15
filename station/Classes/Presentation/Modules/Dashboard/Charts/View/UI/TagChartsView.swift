import UIKit
import Charts
import RuuviLocal
import RuuviOntology
import RuuviService

protocol TagChartsViewDelegate: NSObjectProtocol {
    func chartDidTranslate(_ chartView: TagChartsView)
    func chartValueDidSelect(_ chartView: TagChartsView,
                             entry: ChartDataEntry,
                             highlight: Highlight)
    func chartValueDidDeselect(_ chartView: TagChartsView)
}

class TagChartsView: LineChartView {
    weak var chartDelegate: TagChartsViewDelegate?

    private var settings: RuuviLocalSettings!
    private var chartName: String = ""

    private lazy var chartNameLabel: UILabel = {
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
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout
    private func addSubviews() {
        self.addSubview(chartNameLabel)
        chartNameLabel.anchor(top: nil,
                              leading: nil,
                              bottom: bottomAnchor,
                              trailing: trailingAnchor,
                              padding: .init(top: 0,
                                             left: 0,
                                             bottom: UIDevice.isTablet() ? 42 : 28,
                                             right: 16))
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
        xAxis.drawAxisLineEnabled = false
        xAxis.drawGridLinesEnabled = true
        xAxis.centerAxisLabelsEnabled = false
        xAxis.granularity = 1
        xAxis.granularityEnabled = true
        xAxis.yOffset = 10.0
        viewPortHandler.setMaximumScaleX(5000)
        viewPortHandler.setMaximumScaleY(30)
        xAxis.setLabelCount(5, force: false)
        xAxis.valueFormatter = XAxisValueFormatter()

        leftAxis.labelPosition = .outsideChart
        leftAxis.labelAlignment = .right
        leftAxis.labelFont = .Muli(.regular, size: UIDevice.isTablet() ? 12 : 10)
        leftAxis.setLabelCount(5, force: true)
        leftAxis.drawGridLinesEnabled = true
        leftAxis.labelTextColor = UIColor.white
        leftAxis.minWidth = UIDevice.isTablet() ? 70.0 : 44.0
        leftAxis.maxWidth = UIDevice.isTablet() ? 70.0 : 44.0
        leftAxis.xOffset = 6.0

        rightAxis.enabled = false

        legend.form = .line
        noDataTextColor = UIColor.clear
        scaleXEnabled = true
        scaleYEnabled = true

        drawMarkers = true
        markerView.chartView = self
        self.marker = markerView
    }

    private func reloadData() {
        data?.notifyDataChanged()
        notifyDataSetChanged()
        invalidate()
    }
}

extension TagChartsView: ChartViewDelegate {
    func chartTranslated(_ chartView: ChartViewBase,
                         dX: CGFloat,
                         dY: CGFloat) {
        chartDelegate?.chartDidTranslate(self)
    }

    func chartScaled(_ chartView: ChartViewBase,
                     scaleX: CGFloat,
                     scaleY: CGFloat) {
        chartDelegate?.chartDidTranslate(self)
    }

    func chartValueSelected(_ chartView: ChartViewBase,
                            entry: ChartDataEntry,
                            highlight: Highlight) {
        chartDelegate?.chartValueDidSelect(self,
                                           entry: entry,
                                           highlight: highlight)
    }

    func chartValueNothingSelected(_ chartView: ChartViewBase) {
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
        leftAxis.axisMinimum = min
        leftAxis.axisMaximum = max
        leftYAxisRenderer = CustomYAxisRenderer(
            viewPortHandler: viewPortHandler,
            axis: leftAxis,
            transformer: getTransformer(forAxis: .left)
        )
    }

    func setXRange(min: TimeInterval, max: TimeInterval) {
        xAxis.axisMinimum = min
        xAxis.axisMaximum = max
    }

    func setXAxisRenderer() {
        let axisRenderer = CustomXAxisRenderer(
            from: 0,
            viewPortHandler: viewPortHandler,
            axis: xAxis,
            transformer: getTransformer(forAxis: .left)
        )
        xAxisRenderer = axisRenderer
        xAxis.setLabelCount(5, force: false)
    }

    func resetCustomAxisMinMax() {
        xAxis.resetCustomAxisMin()
        xAxis.resetCustomAxisMax()
    }

    func setSettings(settings: RuuviLocalSettings) {
        self.settings = settings
    }

    // MARK: - UpdateUI
    func updateDataSet(with newData: [ChartDataEntry],
                       isFirstEntry: Bool) {
        if isFirstEntry {
            let emptyDataSet = LineChartData(dataSet: TagChartsHelper.newDataSet())
            data = emptyDataSet
        }

        for point in newData {
            data?.appendEntry(point, toDataSet: 0)
        }
        reloadData()
    }

    func updateLatest(with entry: ChartDataEntry?,
                      type: MeasurementType,
                      measurementService: RuuviServiceMeasurement,
                      unit: String) {
        guard let entry = entry else { return }
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

    func setChartLabel(with name: String,
                       type: MeasurementType,
                       measurementService: RuuviServiceMeasurement,
                       unit: String) {
        chartName = name
        chartNameLabel.text = name
        if let marker = marker as? TagChartsMarkerView {
            marker.initialise(with: unit,
                              type: type,
                              measurementService: measurementService,
                              parentFrame: self.frame)
        }
    }

    func hideChartNameLabel(hide: Bool) {
        chartNameLabel.alpha = hide ? 0 : 1
    }
}
