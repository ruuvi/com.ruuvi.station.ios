import DGCharts
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
import UIKit

protocol TagChartsViewDelegate: NSObjectProtocol {
    func chartDidTranslate(_ chartView: TagChartsView)
    func chartValueDidSelect(
        _ chartView: TagChartsView,
        entry: ChartDataEntry,
        highlight: Highlight
    )
    func chartValueDidDeselect(_ chartView: TagChartsView)
}

class TagChartsView: UIView {
    weak var chartDelegate: TagChartsViewDelegate?

    // MARK: Private
    private var chartView: TagChartsViewInternal = {
        let view = TagChartsViewInternal()
        return view
    }()

    private lazy var chartNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.Muli(.bold, size: UIDevice.isTablet() ? 18 : 14)
        return label
    }()

    private lazy var chartMinMaxAvgLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.Muli(.regular, size: UIDevice.isTablet() ? 12 : 10)
        return label
    }()

    // MARK: - Private properties
    private var settings: RuuviLocalSettings!
    private var chartName: String = ""
    private var chartMinMaxAvgHiddenConstraints: [NSLayoutConstraint] = []

    // Properties for chart stat
    private var minValue: Double?
    private var maxValue: Double?
    private var avgValue: Double?
    private var latestValue: ChartDataEntry?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Layout
extension TagChartsView {

    private func addSubviews() {
        addSubview(chartNameLabel)
        chartNameLabel.anchor(
            top: topAnchor,
            leading: leadingAnchor,
            bottom: nil,
            trailing: trailingAnchor,
            padding: .init(
                top: 4,
                left: 20,
                bottom: 0,
                right: 0
            )
        )

        addSubview(chartMinMaxAvgLabel)
        chartMinMaxAvgLabel.anchor(
            top: chartNameLabel.bottomAnchor,
            leading: chartNameLabel.leadingAnchor,
            bottom: nil,
            trailing: trailingAnchor,
            padding: .init(
                top: 4, left: 0, bottom: 0, right: 0
            )
        )
        chartMinMaxAvgLabel.isHidden = true
        chartMinMaxAvgHiddenConstraints = [
            chartMinMaxAvgLabel.heightAnchor.constraint(
                equalToConstant: 0
            ),
            chartMinMaxAvgLabel.topAnchor.constraint(
                equalTo: chartNameLabel.bottomAnchor,
                constant: 0
            ),
        ]
        NSLayoutConstraint.deactivate(chartMinMaxAvgHiddenConstraints)

        addSubview(chartView)
        chartView.anchor(
            top: chartMinMaxAvgLabel.bottomAnchor,
            leading: leadingAnchor,
            bottom: bottomAnchor,
            trailing: trailingAnchor
        )
        chartView.chartDelegate = self
    }

}

extension TagChartsView: TagChartsViewInternalDelegate {

    func chartDidTranslate(_ chartView: TagChartsViewInternal) {
        chartDelegate?.chartDidTranslate(self)
    }

    func chartValueDidSelect(
        _ chartView: TagChartsViewInternal,
        entry: ChartDataEntry,
        highlight: Highlight
    ) {
        chartDelegate?.chartValueDidSelect(
            self,
            entry: entry,
            highlight: highlight
        )
    }

    func chartValueDidDeselect(_ chartView: TagChartsViewInternal) {
        chartDelegate?.chartValueDidDeselect(self)
    }
}

extension TagChartsView {
    func localize() {
        chartView.localize()
    }

    func clearChartData() {
        chartView.clearChartData()
    }

    func setYAxisLimit(min: Double, max: Double) {
        chartView.setYAxisLimit(min: min, max: max)
    }

    func setXAxisRenderer() {
        chartView.setXAxisRenderer()
    }

    func resetCustomAxisMinMax() {
        chartView.resetCustomAxisMinMax()
    }

    func setSettings(settings: RuuviLocalSettings) {
        self.settings = settings
        chartView.setSettings(settings: settings)
    }

    // MARK: - UpdateUI

    func updateDataSet(
        with newData: [ChartDataEntry],
        isFirstEntry: Bool,
        firstEntry: RuuviMeasurement?,
        showAlertRangeInGraph: Bool
    ) {
        chartView.updateDataSet(
            with: newData,
            isFirstEntry: isFirstEntry,
            firstEntry: firstEntry,
            showAlertRangeInGraph: showAlertRangeInGraph
        )
    }

    func updateLatest(
        with entry: ChartDataEntry?,
        type: MeasurementType,
        measurementService: RuuviServiceMeasurement,
        unit: String
    ) {
        self.latestValue = entry
        setChartStat(
            min: minValue,
            max: maxValue,
            avg: avgValue,
            type: type,
            measurementService: measurementService
        )
    }

    func setChartLabel(
        with name: String,
        type: MeasurementType,
        measurementService: RuuviServiceMeasurement,
        unit: String
    ) {
        chartName = name
        chartNameLabel.text = name + " (\(unit))"
        chartView.setMarker(
            with: type,
            measurementService: measurementService,
            unit: unit
        )
    }

    func setChartStat(
        min: Double?,
        max: Double?,
        avg: Double?,
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

    func setChartStatVisible(show: Bool) {
        chartMinMaxAvgLabel.isHidden = !show
        if show {
            NSLayoutConstraint.deactivate(chartMinMaxAvgHiddenConstraints)
        } else {
            NSLayoutConstraint.activate(chartMinMaxAvgHiddenConstraints)
        }
    }

    /// The lowest y-index (value on the y-axis) that is still visible on he chart.
    var lowestVisibleY: Double {
        chartView.lowestVisibleY
    }

    /// The highest y-index (value on the y-axis) that is still visible on the chart.
    var highestVisibleY: Double {
        chartView.highestVisibleY
    }

    /// Returns the underlying LineChartView.
    var underlyingView: TagChartsViewInternal {
        return chartView
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
        self.minValue = min
        self.maxValue = max
        self.avgValue = avg

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

        var latestVal = ""
        if let latest = latestValue {
            latestVal = formattedMeasurementString(
                for: type,
                value: latest.y,
                measurementService: measurementService
            )
        }

        return RuuviLocalization.chartLatestMinMaxAvg(
            minValue,
            maxValue,
            avgValue,
            latestVal
        )
    }

    // swiftlint:disable:next cyclomatic_complexity
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
        case .aqi:
            return value?.intValue.stringValue ?? RuuviLocalization.na
        case .co2:
            return measurementService.co2String(for: value)
        case .pm25:
            return measurementService.pm25String(for: value)
        case .pm10:
            return measurementService.pm10String(for: value)
        case .voc:
            return measurementService.vocString(for: value)
        case .nox:
            return measurementService.noxString(for: value)
        case .luminosity:
            return measurementService.luminosityString(for: value)
        case .sound:
            return measurementService.soundAvgString(for: value)
        default:
            return ""
        }
    }
}
