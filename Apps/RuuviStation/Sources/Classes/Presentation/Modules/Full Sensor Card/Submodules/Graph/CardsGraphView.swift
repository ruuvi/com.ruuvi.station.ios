import DGCharts
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
import UIKit

protocol CardsGraphViewDelegate: NSObjectProtocol {
    func chartDidTranslate(_ chartView: CardsGraphView)
    func chartValueDidSelect(
        _ chartView: CardsGraphView,
        entry: ChartDataEntry,
        highlight: Highlight
    )
    func chartValueDidDeselect(_ chartView: CardsGraphView)
    func chartDidSingleTap(_ chartView: CardsGraphView, location: CGPoint)
    func chartMarkerInteractionDidBegin(_ chartView: CardsGraphView)
    func chartMarkerInteractionDidEnd(_ chartView: CardsGraphView)
}

class CardsGraphView: UIView {
    weak var chartDelegate: CardsGraphViewDelegate?

    // MARK: Private
    private lazy var chartView: CardsGraphInternalView = {
        let view = CardsGraphInternalView(
            source: .cards,
            graphType: graphType
        )
        return view
    }()

    private lazy var chartNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.mulish(.bold, size: UIDevice.isTablet() ? 18 : 14)
        return label
    }()

    private lazy var chartMinMaxAvgLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.ruuviCaption1()
        return label
    }()

    // MARK: - Private properties
    private var settings: RuuviLocalSettings!
    private let variant: MeasurementDisplayVariant
    private let graphType: MeasurementType
    var measurementType: MeasurementType { graphType }
    private var chartMinMaxAvgHiddenConstraints: [NSLayoutConstraint] = []

    // Properties for chart stat
    private var minValue: Double?
    private var maxValue: Double?
    private var avgValue: Double?
    private var latestValue: ChartDataEntry?

    init(variant: MeasurementDisplayVariant) {
        self.variant = variant
        self.graphType = variant.type
        super.init(frame: .zero)
        addSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Layout
extension CardsGraphView {

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

extension CardsGraphView: CardsGraphInternalViewDelegate {

    func chartDidTranslate(_ chartView: CardsGraphInternalView) {
        chartDelegate?.chartDidTranslate(self)
    }

    func chartValueDidSelect(
        _ chartView: CardsGraphInternalView,
        entry: ChartDataEntry,
        highlight: Highlight
    ) {
        chartDelegate?.chartValueDidSelect(
            self,
            entry: entry,
            highlight: highlight
        )
    }

    func chartValueDidDeselect(_ chartView: CardsGraphInternalView) {
        chartDelegate?.chartValueDidDeselect(self)
    }

    func chartDidSingleTap(
        _ chartView: CardsGraphInternalView,
        location: CGPoint
    ) {
        chartDelegate?.chartDidSingleTap(self, location: location)
    }

    func chartMarkerInteractionDidBegin(_ chartView: CardsGraphInternalView) {
        chartDelegate?.chartMarkerInteractionDidBegin(self)
    }

    func chartMarkerInteractionDidEnd(_ chartView: CardsGraphInternalView) {
        chartDelegate?.chartMarkerInteractionDidEnd(self)
    }
}

extension CardsGraphView {
    func localize() {
        chartView.localize()
    }

    func clearChartData() {
        chartView.clearChartData()
    }

    func setYAxisLimit(min: Double, max: Double) {
        chartView.setYAxisLimit(min: min, max: max)
    }

    func setXAxisRenderer(showAll: Bool) {
        chartView.setXAxisRenderer(showAll: showAll)
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
        type: MeasurementType,
        measurementService: RuuviServiceMeasurement,
        unit: String
    ) {
        let hideUnit = MeasurementType.hideUnit(for: type)
        chartNameLabel.text = type.shortName(for: variant) + (hideUnit ? "" : " (\(unit))")
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
    var underlyingView: CardsGraphInternalView {
        return chartView
    }
}

extension CardsGraphView {

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
        guard let value else { return "" }

        switch type {
        case .temperature:
            let decimals = settings?.temperatureAccuracy.value ?? 2
            return formattedNumber(value, decimals: decimals)
        case .humidity:
            let resolvedUnit = variant.humidityUnit ?? .percent
            switch resolvedUnit {
            case .dew:
                let decimals = settings?.temperatureAccuracy.value ?? 2
                return formattedNumber(value, decimals: decimals)
            default:
                let decimals = settings?.humidityAccuracy.value ?? 2
                return formattedNumber(value, decimals: decimals)
            }
        case .pressure:
            let defaultUnit = settings?.pressureUnit ?? .hectopascals
            let pressureUnit = variant.resolvedPressureUnit(default: defaultUnit)
            let accuracy = settings?.pressureAccuracy ?? .two
            let decimals = pressureUnit.resolvedAccuracyValue(from: accuracy)
            return formattedNumber(value, decimals: decimals)
        case .aqi:
            return measurementService.aqiString(for: value)
        case .co2:
            return measurementService.co2String(for: value)
        case .pm10:
            return measurementService.pm10String(for: value)
        case .pm25:
            return measurementService.pm25String(for: value)
        case .pm40:
            return measurementService.pm40String(for: value)
        case .pm100:
            return measurementService.pm100String(for: value)
        case .voc:
            return measurementService.vocString(for: value)
        case .nox:
            return measurementService.noxString(for: value)
        case .luminosity:
            return measurementService.luminosityString(for: value)
        case .soundInstant, .soundPeak, .soundAverage:
            return measurementService.soundString(for: value)
        default:
            let decimals = 2
            return formattedNumber(value, decimals: decimals)
        }
    }

    private func formattedNumber(_ value: Double, decimals: Int) -> String {
        GlobalHelpers().formattedString(
            from: value,
            minPlace: 0,
            toPlace: decimals
        )
    }
}
