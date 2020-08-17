import UIKit
import Charts

class TagChartView: LineChartView {
    lazy var unitLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 11)
        return label
    }()

    lazy var progressView: ProgressBarView = {
        let progressView = ProgressBarView(frame: .zero)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.layer.cornerRadius = 12
        progressView.isHidden = true
        return progressView
    }()
    var viewModel: TagChartViewModel! {
        didSet {
            updateUIViewModel()
        }
    }
    weak var presenter: TagChartViewOutput?
// MARK: - LifeCycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        addSubviews()
        makeConstraints()
        configure()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
// MARK: - Layout
    private func addSubviews() {
        self.addSubview(unitLabel)
        self.addSubview(progressView)
    }

    private func makeConstraints() {
        setUnitLabelConstraints()
        setProgressViewConstraints()
    }

    private func setUnitLabelConstraints() {
        addConstraint(NSLayoutConstraint(item: unitLabel,
                                         attribute: .trailing,
                                         relatedBy: .equal,
                                         toItem: self,
                                         attribute: .trailing,
                                         multiplier: 1.0,
                                         constant: -16))
        addConstraint(NSLayoutConstraint(item: unitLabel,
                                         attribute: .top,
                                         relatedBy: .equal,
                                         toItem: self,
                                         attribute: .top,
                                         multiplier: 1.0,
                                         constant: 10))
    }

    private func setProgressViewConstraints() {
        addConstraint(NSLayoutConstraint(item: progressView,
                                         attribute: .centerX,
                                         relatedBy: .equal,
                                         toItem: self,
                                         attribute: .centerX,
                                         multiplier: 1.0,
                                         constant: 0.0))
        addConstraint(NSLayoutConstraint(item: progressView,
                                         attribute: .centerY,
                                         relatedBy: .equal,
                                         toItem: self,
                                         attribute: .centerY,
                                         multiplier: 1.0,
                                         constant: 44.0))
        addConstraint(NSLayoutConstraint(item: progressView,
                                         attribute: .height,
                                         relatedBy: .equal,
                                         toItem: nil,
                                         attribute: .notAnAttribute,
                                         multiplier: 1.0,
                                         constant: 24.0))
        addConstraint(NSLayoutConstraint(item: progressView,
                                         attribute: .width,
                                         relatedBy: .equal,
                                         toItem: self,
                                         attribute: .width,
                                         multiplier: 0.5,
                                         constant: 0.0))
    }
// MARK: - UpdateUI
    private func updateUIViewModel() {
        bind(viewModel.chartData) { (view, data) in
            view.data = data
            view.data?.notifyDataChanged()
        }
        progressView.bind(viewModel.progress) { (view, progress) in
            if let progress = progress {
                view.setProgress(progress, animated: true)
            }
        }
        unitLabel.bind(viewModel.unit) { (label, unit) in
            if let unit = unit {
                label.text = unit.symbol.localized()
            }
        }
    }
// MARK: - Private
    private func configure() {
        chartDescription?.enabled = false
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
        xAxis.granularity = 59.9
        xAxis.valueFormatter = DateValueFormatter()
        xAxis.granularityEnabled = true
        leftAxis.labelPosition = .outsideChart
        leftAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
        leftAxis.drawGridLinesEnabled = true
        leftAxis.labelTextColor = UIColor.white
        leftAxis.minWidth = 2.0
        rightAxis.enabled = false
        legend.form = .line
        noDataTextColor = UIColor.white
        noDataText = "TagCharts.NoChartData.text".localized()
        scaleXEnabled = true
        scaleYEnabled = true
    }

    private func getOffset(dX: CGFloat, dY: CGFloat) -> TimeInterval {
        var pt = CGPoint(
            x: viewPortHandler.contentLeft + dX,
            y: viewPortHandler.contentBottom + dY)
        getTransformer(forAxis: .left).pixelToValues(&pt)
        return lowestVisibleX - max(xAxis.axisMinimum, Double(pt.x))
    }

    private func getScaleOffset(scaleX: CGFloat, scaleY: CGFloat) -> TimeInterval {
        var pt = CGPoint(
            x: viewPortHandler.contentLeft / scaleX,
            y: viewPortHandler.contentBottom / scaleY)
        getTransformer(forAxis: .left).pixelToValues(&pt)
        return lowestVisibleX - max(xAxis.axisMinimum, Double(pt.x))
    }
}
// MARK: - TagChartViewInput
extension TagChartView: TagChartViewInput {
    var chartView: TagChartView {
        return self
    }

    func configure(with viewModel: TagChartViewModel) {
        self.viewModel = viewModel
    }

    func localize() {
        noDataText = "TagCharts.NoChartData.text".localized()
    }

    func clearChartData() {
        clearValues()
        resetCustomAxisMinMax()
        resetZoom()
    }

    func setXRange(min: TimeInterval, max: TimeInterval) {
        xAxis.axisMinimum = min
        xAxis.axisMaximum = max
    }

    func resetCustomAxisMinMax() {
        xAxis.resetCustomAxisMin()
        xAxis.resetCustomAxisMax()
    }

    func fitZoomTo(min: TimeInterval, max: TimeInterval) {
        let scaleX = CGFloat(xAxis.axisMaximum - xAxis.axisMinimum) / CGFloat((max - min))
        zoom(scaleX: 0, scaleY: 0, x: 0, y: 0)
        zoom(scaleX: scaleX, scaleY: 0, x: 0, y: 0)
        moveViewToX(min)
    }

    func reloadData() {
        data?.notifyDataChanged()
        notifyDataSetChanged()
    }
}
extension TagChartView: ChartViewDelegate {
    func chartTranslated(_ chartView: ChartViewBase, dX: CGFloat, dY: CGFloat) {
        guard viewModel.isDownsamplingOn.value == true else {
            return
        }
        let offset = getOffset(dX: dX, dY: dY)
        let newVisibleRange = (min: lowestVisibleX - offset * 2, max: highestVisibleX + offset * 2)
        presenter?.didChartChangeVisibleRange(self, newRange: newVisibleRange)
    }
    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        let offset = getScaleOffset(scaleX: scaleX, scaleY: scaleY)
        let newVisibleRange = (min: lowestVisibleX - offset * 2, max: highestVisibleX + offset * 2)
        presenter?.didChartChangeVisibleRange(self, newRange: newVisibleRange)
    }
}
