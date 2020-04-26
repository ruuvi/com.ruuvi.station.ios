import UIKit
import Humidity
import Charts

enum TagChartsType {
    case ruuvi
    case web
}

struct TagChartsPoint {
    var date: Date
    var value: Double
}

struct TagChartsViewModel {
    var type: TagChartsType = .ruuvi
    var uuid: Observable<String?> = Observable<String?>(UUID().uuidString)
    var name: Observable<String?> = Observable<String?>()
    var background: Observable<UIImage?> = Observable<UIImage?>()
    var temperatureUnit: Observable<TemperatureUnit?> = Observable<TemperatureUnit?>()
    var humidityUnit: Observable<HumidityUnit?> = Observable<HumidityUnit?>()
    var isConnectable: Observable<Bool?> = Observable<Bool?>()
    var alertState: Observable<AlertState?> = Observable<AlertState?>()
    var isConnected: Observable<Bool?> = Observable<Bool?>()
    var temperatureChartData: Observable<LineChartData?> = Observable<LineChartData?>()
    var humidityChartData: Observable<LineChartData?> = Observable<LineChartData?>()
    var pressureChartData: Observable<LineChartData?> = Observable<LineChartData?>()
    var temperatureChart: Observable<TagChartViewInput?> = Observable<TagChartViewInput?>()
    var humidityChart: Observable<TagChartViewInput?> = Observable<TagChartViewInput?>()
    var pressureChart: Observable<TagChartViewInput?> = Observable<TagChartViewInput?>()

    init(_ ruuviTag: RuuviTagRealm) {
        type = .ruuvi
        uuid.value = ruuviTag.uuid
        name.value = ruuviTag.name
        isConnectable.value = ruuviTag.isConnectable
    }

    init(_ webTag: WebTagRealm) {
        type = .web
        uuid.value = webTag.uuid
        name.value = webTag.name
        isConnectable.value = false
    }
}
// MARK: - charts methods
extension TagChartsViewModel {
    @discardableResult
    func chartData(for type: MeasurementType) -> LineChartData {
        var chartData: LineChartData = LineChartData(dataSet: TagChartsPresenter.newDataSet())
        switch type {
        case .temperature:
            if let data = temperatureChartData.value {
                chartData = data
            } else {
                temperatureChartData.value = chartData
            }
        case .humidity:
            if let data = humidityChartData.value {
                chartData = data
            } else {
                humidityChartData.value = chartData
            }
        case .pressure:
            if let data = pressureChartData.value {
                chartData = data
            } else {
                pressureChartData.value = chartData
            }
        default:
            fatalError("\(#function):\(#line) Undeclarated chart type")
        }
        return chartData
    }

    func clearChartsData() {
        MeasurementType.chartsCases.forEach({
            clearChartData(for: $0)
        })
    }

    func clearChartData(for type: MeasurementType) {
        switch type {
        case .temperature:
            self.temperatureChart.value?.clearChartData()
        case .humidity:
            self.humidityChart.value?.clearChartData()
        case .pressure:
            self.pressureChart.value?.clearChartData()
        default:
            return
        }
    }

    func fitScreen(with type: MeasurementType) {
        switch type {
        case .temperature:
            self.temperatureChart.value?.fitScreen()
        case .humidity:
            self.humidityChart.value?.fitScreen()
        case .pressure:
            self.pressureChart.value?.fitScreen()
        default:
            return
        }
    }

    func fitZoomTo(start: TimeInterval,
                   end: TimeInterval,
                   for type: MeasurementType) {
        switch type {
        case .temperature:
            self.temperatureChart.value?.fitZoomTo(min: start, max: end)
        case .humidity:
            self.humidityChart.value?.fitZoomTo(min: start, max: end)
        case .pressure:
            self.pressureChart.value?.fitZoomTo(min: start, max: end)
        default:
            return
        }
    }

    func reloadChartData(with type: MeasurementType) {
        switch type {
        case .temperature:
            self.temperatureChart.value?.reloadData()
        case .humidity:
            self.humidityChart.value?.reloadData()
        case .pressure:
            self.pressureChart.value?.reloadData()
        default:
            return
        }
    }

    func resetCustomAxisMinMax(for type: MeasurementType) {
        switch type {
        case .temperature:
            self.temperatureChart.value?.reloadData()
        case .humidity:
            self.humidityChart.value?.reloadData()
        case .pressure:
            self.pressureChart.value?.reloadData()
        default:
            return
        }
    }

    func setRange(min: TimeInterval,
                  max: TimeInterval,
                  for type: MeasurementType) {
        switch type {
        case .temperature:
            self.temperatureChart.value?.setXRange(min: min, max: max)
        case .humidity:
            self.humidityChart.value?.setXRange(min: min, max: max)
        case .pressure:
            self.pressureChart.value?.setXRange(min: min, max: max)
        default:
            return
        }
    }
}
