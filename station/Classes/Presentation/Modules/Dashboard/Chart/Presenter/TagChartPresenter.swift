import Foundation
import Charts

class TagChartPresenter: NSObject {
    var view: TagChartViewInput!
    var settings: Settings!
    var viewModel = TagChartViewModel()
    weak var ouptut: TagChartModuleOutput!
    var dataSource: [RuuviMeasurement] = [] {
        didSet {
            if oldValue.count == 0,
                dataSource.count > 0 {
                createChartData()
            } else {
                handleEmptyResults()
            }
        }
    }

    private let threshold: Int = 100
    private var type: MeasurementType!
    private var lastMeasurement: RuuviMeasurement?
    private lazy var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        queue.name = "com.ruuvi.station.TagChartsPresenter.\(self.type.rawValue)"
        queue.qualityOfService = .userInteractive
        return queue
    }()
    private var chartData: LineChartData? {
        return viewModel.chartData.value
    }
}
// MARK: - TagChartModuleInput
extension TagChartPresenter: TagChartModuleInput {
    func configure(type: MeasurementType, output: TagChartModuleOutput) {
        self.type = type
        self.bind(output.dataSource) { (presenter, dataSource) in
            if let dataSource = dataSource {
                presenter.dataSource = dataSource
            }
        }
    }
}

extension TagChartPresenter: TagChartViewOutput {
    func didChartChangeVisibleRange(_ chartView: TagChartView, newRange range: (min: TimeInterval, max: TimeInterval)) {
        fetchPointsByDates(start: range.min,
                           stop: range.max)
    }
}

extension TagChartPresenter {
    private func handleEmptyResults() {
        view.clearChartData()
        if let last = lastMeasurement {
            setDownSampled(dataSet: [last],
                           completion: { [weak self] in
                self?.view.reloadData()
                self?.view.fitScreen()
            })
        }
    }

    private func createChartData() {
        let currentDate = Date().timeIntervalSince1970
        if let chartDurationThreshold = Calendar.current.date(byAdding: .hour,
                                                              value: -settings.chartDurationHours,
                                                              to: Date())?.timeIntervalSince1970,
            let firstDate = dataSource.first?.date.timeIntervalSince1970,
            let lastDate = dataSource.last?.date.timeIntervalSince1970,
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
            setDownSampled(dataSet: dataSource,
                           completion: { [weak self] in
                self?.view.reloadData()
            })
        }
    }

    private func handleUpdateRuuviTagData(_ results: [RuuviTagSensorRecord]) {
        let newValues: [RuuviMeasurement] = results.map({ $0.measurement })
        dataSource.append(contentsOf: newValues)
        insertMeasurements(newValues)
//        let chartIntervalSeconds = settings.chartIntervalSeconds
//        insertions.forEach({ i in
//            let newValue = results[i].measurement
//            let elapsed = Int(newValue.date.timeIntervalSince(lastChartSyncDate))
//            if elapsed >= chartIntervalSeconds {
//                lastChartSyncDate = newValue.date
//                ruuviTagData.append(newValue)
//                insertMeasurements([newValue], into: viewModel)
//            }
//        })
    }
    private func insertMeasurements(_ newValues: [RuuviMeasurement]) {
        newValues.forEach {
            viewModel.chartData.value?.addEntry(chartEntry(for: $0), dataSetIndex: 0)
            viewModel.chartData.value?.notifyDataChanged()
        }
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
        let filterOperation = ChartFilterOperation(array: dataSource,
                                                   threshold: threshold,
                                                   type: type,
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
    private func chartEntry(for data: RuuviMeasurement) -> ChartDataEntry {
        let value: Double?
        switch type {
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
        return ChartDataEntry(x: data.date.timeIntervalSince1970, y: y)
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
            let chartDataSet = TagChartsPresenter.newDataSet()
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
            chartData.addEntry(ChartDataEntry(x: max_area_point.0, y: max_area_point.1), dataSetIndex: 0)
            a = next_a // This a is the next a (chosen b)
        }
        chartData.addEntry(chartEntry(for: dataSet[dataSet.count - 2]), dataSetIndex: 0)
        chartData.addEntry(chartEntry(for: dataSet[dataSet.count - 1]), dataSetIndex: 0)
    }
    // swiftlint:enable function_body_length
}
