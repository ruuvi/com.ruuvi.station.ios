import Foundation
import Charts

class TagChartPresenter: NSObject {
    var view: TagChartViewInput!
    var settings: Settings!
    var viewModel: TagChartViewModel! {
        didSet {
            self.view.configure(with: viewModel)
        }
    }
    weak var ouptut: TagChartModuleOutput!

    private let threshold: Int = 100
    private lazy var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        queue.name = "com.ruuvi.station.TagChartsPresenter.\(self.viewModel.type.rawValue)"
        queue.qualityOfService = .userInteractive
        return queue
    }()
    private var chartData: LineChartData? {
        return viewModel.chartData.value
    }
}
// MARK: - TagChartModuleInput
extension TagChartPresenter: TagChartModuleInput {
    var chartView: TagChartView {
        return view.chartView
    }

    fileprivate func configureViewModel(_ viewModel: TagChartViewModel) {
        switch viewModel.type {
        case .temperature:
            viewModel.unit.value = settings.temperatureUnit.unitTemperature
        case .humidity:
            switch settings.humidityUnit {
            case .dew:
                viewModel.unit.value = settings.temperatureUnit.unitTemperature
            case .percent:
                viewModel.unit.value = Unit(symbol: "%".localized())
            case .gm3:
                viewModel.unit.value = Unit(symbol: "g/m³".localized())
            }
        case .pressure:
            viewModel.unit.value =  Unit(symbol: "hPa".localized())
        default:
            viewModel.unit.value = Unit(symbol: "N/A".localized())
        }
        self.viewModel = viewModel
    }

    func configure(_ viewModel: TagChartViewModel, output: TagChartModuleOutput) {
        configureViewModel(viewModel)
        self.ouptut = output
    }

    func clearChartData() {
        view.clearChartData()
    }

    func reloadChart() {
        if ouptut.dataSource.count == 0 {
            handleEmptyResults()
        } else {
            createChartData()
        }
    }

    func setProgress(_ value: Float) {
        viewModel.progress.value = value
    }

    func notifySettingsChanged() {
        configureViewModel(viewModel)
        createChartData()
    }
}

extension TagChartPresenter: TagChartViewOutput {
    func didChartChangeVisibleRange(_ chartView: TagChartView, newRange range: (min: TimeInterval, max: TimeInterval)) {
        fetchPointsByDates(start: range.min,
                           stop: range.max)
    }
}

extension TagChartPresenter {
    private func newDataSet() -> LineChartDataSet {
        let lineChartDataSet = LineChartDataSet()
        lineChartDataSet.axisDependency = .left
        lineChartDataSet.setColor(UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1))
        lineChartDataSet.lineWidth = 1.5
        lineChartDataSet.drawCirclesEnabled = true
        lineChartDataSet.drawValuesEnabled = false
        lineChartDataSet.fillAlpha = 0.26
        lineChartDataSet.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
        lineChartDataSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        lineChartDataSet.drawCircleHoleEnabled = false
        lineChartDataSet.drawFilledEnabled = true
        lineChartDataSet.highlightEnabled = false
        return lineChartDataSet
    }
    private func handleEmptyResults() {
        view.clearChartData()
        if let last = ouptut.lastMeasurement {
            setDownSampled(dataSet: [last],
                           completion: { [weak self] in
                self?.view.reloadData()
                self?.view.fitScreen()
            })
        }
    }

    private func createChartData() {
        viewModel.chartData.value = LineChartData(dataSet: newDataSet())
        let currentDate = Date().timeIntervalSince1970
        if let chartDurationThreshold = Calendar.current.date(byAdding: .hour,
                                                              value: -settings.chartDurationHours,
                                                              to: Date())?.timeIntervalSince1970,
            let firstDate = ouptut.dataSource.first?.date.timeIntervalSince1970,
            let lastDate = ouptut.dataSource.last?.date.timeIntervalSince1970,
            (lastDate - firstDate) > (currentDate - chartDurationThreshold) {
            fetchPointsByDates(start: chartDurationThreshold,
                               stop: currentDate,
                               completion: { [weak self] in
                self?.view.setXRange(min: firstDate, max: currentDate)
                self?.view.reloadData()
                self?.view.fitZoomTo(min: chartDurationThreshold, max: currentDate)
                self?.view.resetCustomAxisMinMax()
            })
        } else {
            setDownSampled(dataSet: ouptut.dataSource,
                           completion: { [weak self] in
                self?.view.reloadData()
            })
        }
    }

    func insertMeasurements(_ newValues: [RuuviMeasurement]) {
        guard let chartData = viewModel.chartData.value else {
            return
        }
        newValues.forEach {
            chartData.addEntry(chartEntry(for: $0), dataSetIndex: 0)
            chartData.notifyDataChanged()
        }
        drawCirclesIfNeeded(for: chartData)
        view.reloadData()
    }

    private func drawCirclesIfNeeded(for chartData: LineChartData?) {
        if let dataSet = chartData?.dataSets.first as? LineChartDataSet {
            switch dataSet.entries.count {
            case 1:
                dataSet.circleRadius = 6
                dataSet.drawCirclesEnabled = true
            case 2...threshold:
                dataSet.circleRadius = 2
                dataSet.drawCirclesEnabled = true
            default:
                dataSet.drawCirclesEnabled = false
            }
        }
    }

    private func fetchPointsByDates(start: TimeInterval,
                                    stop: TimeInterval,
                                    completion: (() -> Void)? = nil) {
        queue.operations.forEach({
            if !$0.isExecuting {
                $0.cancel()
            }
        })
        let filterOperation = ChartFilterOperation(array: ouptut.dataSource,
                                                   threshold: threshold,
                                                   type: viewModel.type,
                                                   start: start,
                                                   end: stop)
        filterOperation.completionBlock = { [unowned filterOperation] in
            if !filterOperation.isCancelled {
                let sorted = filterOperation.sorted
                DispatchQueue.main.async {
                    self.setDownSampled(dataSet: sorted,
                                        completion: completion)
                }
            }
        }
        queue.addOperation(filterOperation)
    }
//swiftlint:disable:next cyclomatic_complexity
    private func chartEntry(for data: RuuviMeasurement) -> ChartDataEntry {
        var value: Double?
        switch viewModel.type {
        case .temperature:
            value = data.temperature?.converted(to: settings.temperatureUnit.unitTemperature).value
        case .humidity:
            switch settings.humidityUnit {
            case .dew:
                switch settings.temperatureUnit {
                case .celsius:
                    value = data.humidity?.Td
                case .fahrenheit:
                    value = data.humidity?.TdF
                case .kelvin:
                    value = data.humidity?.TdK
                }
            case .gm3:
                value = data.humidity?.ah
            case .percent:
                if let relativeHumidity = data.humidity?.rh {
                    value = relativeHumidity * 100
                } else {
                    value = nil
                }
            }
        case .pressure:
            value = data.pressure?.converted(to: .hectopascals).value
        default:
            fatalError("before need implement chart with current type!")
        }
        guard let y = value else {
            fatalError("before need implement chart with current type!")
        }
        return ChartDataEntry(x: data.date.timeIntervalSince1970, y: Double(round(100*y)/100))
    }
    // swiftlint:disable function_body_length
    private func setDownSampled(dataSet: [RuuviMeasurement], completion: (() -> Void)? = nil) {
        defer {
            completion?()
        }
        guard let chartData = chartData else {
            return
        }
        if let chartDataSet = chartData.dataSets.first as? LineChartDataSet {
            chartDataSet.removeAll(keepingCapacity: true)
            chartDataSet.drawCirclesEnabled = false
        } else {
            let chartDataSet = newDataSet()
            chartDataSet.drawCirclesEnabled = false
            chartData.addDataSet(chartDataSet)
        }
        let data_length = dataSet.count
        if data_length <= threshold {
            dataSet.forEach({
                chartData.addEntry(chartEntry(for: $0), dataSetIndex: 0)
            })
            drawCirclesIfNeeded(for: chartData)
            return // Nothing to do
        }
        // Bucket size. Leave room for start and end data points
        let every = (data_length - 4) / (threshold - 4)
        var a = 1  // Initially a is the first point in the triangle
        var max_area_point: (Double, Double) = (0, 0)
        var max_area: Double = 0
        var area: Double = 0
        var next_a: Int = 0
        var avg_x: Double = 0
        var avg_y: Double = 0
        var avg_range_start: Int = 0
        var avg_range_end: Int = 0
        var avg_range_length: Int = 0
        var range_offs: Int = 0
        var range_to: Int = 0
        var point_a_x: Double = 0
        var point_a_y: Double = 0
        chartData.addEntry(chartEntry(for: dataSet[0]), dataSetIndex: 0)
        chartData.addEntry(chartEntry(for: dataSet[1]), dataSetIndex: 0)
        for i in 0..<data_length/every {
            // Calculate point average for next bucket (containing c)
            avg_x = 0
            avg_y = 0
            avg_range_start  = Int( floor( Double( ( i + 1 ) * every) ) + 1)
            avg_range_end    = Int( floor( Double( ( i + 2 ) * every) ) + 1)
            avg_range_end = avg_range_end < data_length ? avg_range_end : data_length
            avg_range_length = avg_range_end - avg_range_start
            guard avg_range_length > 0 else {
                if a < data_length {
                    chartData.addEntry(chartEntry(for: dataSet[a]), dataSetIndex: 0)
                    a += every
                }
                continue
            }
            for range_start in avg_range_start..<avg_range_end {
                let point_a = chartEntry(for: dataSet[range_start])
                avg_x += point_a.x
                avg_y += point_a.y
            }
            avg_x /= Double(avg_range_length)
            avg_y /= Double(avg_range_length)
            // Get the range for this bucket
            range_offs = Int(floor( Double(i * every) ) + 1)
            range_to   = Int(floor( Double((i + 1) * every) ) + 1)
            // Point a
            let point_a = chartEntry(for: dataSet[a])
            point_a_x = point_a.x
            point_a_y = point_a.y
            max_area = -1
            area = -1
            for range_offs in range_offs..<range_to {
                // Calculate triangle area over three buckets
                let point_offs = chartEntry(for: dataSet[range_offs])
                area = abs( ( point_a_x - avg_x ) * ( point_offs.y  - point_a_y ) -
                    ( point_a_x - point_offs.x ) * ( avg_y - point_a_y )
                )
                area *= 0.5
                if area > max_area {
                    max_area = area
                    max_area_point = (point_offs.x, point_offs.y)
                    next_a = range_offs // Next a is this b
                }
            }
            chartData.addEntry(ChartDataEntry(x: max_area_point.0, y: Double(round(100 * max_area_point.1)/100)), dataSetIndex: 0)
            a = next_a // This a is the next a (chosen b)
        }
        chartData.addEntry(chartEntry(for: dataSet[dataSet.count - 2]), dataSetIndex: 0)
        chartData.addEntry(chartEntry(for: dataSet[dataSet.count - 1]), dataSetIndex: 0)
    }
    // swiftlint:enable function_body_length
}
