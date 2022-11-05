import UIKit
import Charts
import RuuviLocal

protocol TagChartsViewDelegate: NSObjectProtocol {
    func chartDidTranslate(_ chartView: TagChartsView)
}

class TagChartsView: LineChartView {
    weak var chartDelegate: TagChartsViewDelegate?

    private var settings: RuuviLocalSettings!

    private lazy var chartNameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 11)
        return label
    }()

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
                              padding: .init(top: 0, left: 0, bottom: 40, right: 16))
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
        xAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
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
        xAxis.valueFormatter = DateValueFormatter(with: Locale.current)

        leftAxis.labelPosition = .outsideChart
        leftAxis.labelFont = .systemFont(ofSize: 8, weight: .regular)
        leftAxis.setLabelCount(5, force: true)
        leftAxis.drawGridLinesEnabled = true
        leftAxis.labelTextColor = UIColor.white
        leftAxis.minWidth = 40.0
        leftAxis.maxWidth = 40.0
        leftAxis.xOffset = 8.0

        rightAxis.enabled = false

        legend.form = .line
        noDataTextColor = UIColor.clear
        scaleXEnabled = true
        scaleYEnabled = true
    }

    private func reloadData() {
        data?.notifyDataChanged()
        notifyDataSetChanged()
        invalidate()
    }
}

extension TagChartsView: ChartViewDelegate {
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        chartDelegate?.chartDidTranslate(self)
    }

    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        chartDelegate?.chartDidTranslate(self)
    }
}

extension TagChartsView {

    func localize() {
        xAxis.valueFormatter = DateValueFormatter(with: settings.language.locale)
        leftAxis.valueFormatter = YAxisValueFormatter(with: settings.language.locale)
    }

    func clearChartData() {
        clearValues()
        resetCustomAxisMinMax()
        resetZoom()
        reloadData()
        fitScreen()
    }

    func setYAxisLimit(min: Double, max: Double) {
        leftAxis.axisMinimum = min - 0.5
        leftAxis.axisMaximum = max + 0.5
    }

    func setXRange(min: TimeInterval, max: TimeInterval) {
        xAxis.axisMinimum = min
        xAxis.axisMaximum = max
    }

    func setXAxisRenderer() {
        let axisRenderer = CustomXAxisRenderer(from: 0,
                                               viewPortHandler: viewPortHandler,
                                               axis: xAxis,
                                               transformer: getTransformer(forAxis: .left))
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

    func setChartLabel(with name: String,
                       unit: String) {
        chartNameLabel.text = name + "(\(unit))"
    }

}
