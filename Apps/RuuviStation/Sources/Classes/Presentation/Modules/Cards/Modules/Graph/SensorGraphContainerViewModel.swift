//import Combine
//import SwiftUI
//
//class SensorGraphContainerViewModel: ObservableObject {
//    // Published properties for UI
////    @Published var sensors: [SensorViewModel] = []
//    @Published var activeCardIndex: Int = 0
//    @Published var isLoading: Bool = false
//
//    // Dependencies
//    private let coordinator: CardsCoordinator
//    private var cancellables = Set<AnyCancellable>()
//
//    init(coordinator: CardsCoordinator) {
//        self.coordinator = coordinator
//
////        // Subscribe to coordinator's publishers
////        coordinator.measurementTabData
////            .receive(on: RunLoop.main)
////            .sink { [weak self] sensors in
////                self?.sensors = sensors
////            }
////            .store(in: &cancellables)
////
////        coordinator.activeCardData
////            .receive(on: RunLoop.main)
////            .sink { [weak self] _ in
////                // Process active card data
////            }
////            .store(in: &cancellables)
//    }
//
//    // MARK: - User Actions
//
//    func onCardSwiped(to index: Int) {
//        activeCardIndex = index
////        coordinator.setActiveCard(index: index)
//    }
//
//    func refresh() {
//        // Refresh data
//    }
//}

import Foundation
import SwiftUI
import RuuviOntology
import Combine
import DGCharts
import RuuviService
import RuuviLocal

class SensorGraphContainerViewModel: ObservableObject, NewCardsInteractorOutput {
    // UI coordination state
    @Published var activeSensor: RuuviTagSensor?

    @Published var highlightedX: Double? = nil
    @Published var scaledChart: TagChartsView? = nil

    // Chart configuration state
    @Published var chartDurationHours: Int
    @Published var showAllPoints: Bool = true
    @Published var showChartStat: Bool = true
    @Published var showAlertRangeInGraph: Bool = true
    @Published var isFirstEntry: Bool = true
    @Published var updateDataSet: Bool = false
    @Published var graphViewModels: [SensorGraphViewModel] = []

    @Published var isLoading: Bool = false

    let measurementService: RuuviServiceMeasurement

    // Services and dependencies
    private let interactor: NewCardsInteractorInput
    private let settings: RuuviLocalSettings

    private let coordinator: CardsCoordinator
    private var cancellables = Set<AnyCancellable>()

    init(
        coordinator: CardsCoordinator,
        interactor: NewCardsInteractorInput
    ) {
        self.interactor = interactor
        self.coordinator = coordinator

        let r = AppAssembly.shared.assembler.resolver
        self.measurementService = r.resolve(RuuviServiceMeasurement.self)!
        self.settings = r.resolve(RuuviLocalSettings.self)!
        self.chartDurationHours = settings.chartDurationHours

        // Connect to interactor
        (interactor as? NewCardsInteractor)?.presenter = self

        coordinator.activeSensorData
            .receive(on: RunLoop.main)
            .sink { [weak self] activeSensor in
                self?.activeSensor = activeSensor
                self?.onAppear()
                print(activeSensor?.name)
            }
            .store(in: &cancellables)

//        // Subscribe to settings changes
//        settings.$chartDurationHours
//            .sink { [weak self] newValue in
//                self?.chartDurationHours = newValue
//                self?.reloadCharts()
//            }
//            .store(in: &cancellables)
//
//        settings.$showMinMaxAvg
//            .sink { [weak self] newValue in
//                self?.showChartStat = newValue
//                self?.objectWillChange.send()
//            }
//            .store(in: &cancellables)
    }

    deinit {
        interactor.stopObservingRuuviTagsData()
        interactor.stopObservingTags()
    }

    // MARK: User actions
    func onAppear() {
        if let activeSensor = activeSensor {
            interactor.configure(withTag: activeSensor.any, andSettings: nil)
//            interactor.restartObservingData()
        }
    }

    func onCardSwiped(to index: Int) {
        // Handle card swipe
    }

    // MARK: - UI Interaction Methods

    func chartDidTranslate(_ chartView: TagChartsView) {
        scaledChart = chartView
    }

    func updateHighlight(x: Double?) {
        highlightedX = x
    }

    func toggleShowStatistics(_ show: Bool) {
        showChartStat = show
        interactor.updateChartShowMinMaxAvgSetting(with: show)
    }

    func reloadCharts() {
        updateDataSet = true
        interactor.restartObservingData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateDataSet = false
        }
    }

    func stopObserving() {
        interactor.stopObservingRuuviTagsData()
    }

    // MARK: - NewCardsInteractorOutput Implementation

    func createChartModules(
        from: [MeasurementType],
        for sensor: RuuviTagSensor
    ) {
        // Create chart entities for each measurement type
        let newChartEntities = from.map { type -> SensorGraphEntity in
            return SensorGraphEntity(
                ruuviTagId: sensor.id,
                graphType: type,
                dataSet: [],
                graphData: nil,
                upperAlertValue: nil,
                lowerAlertValue: nil,
                unit: getMeasurementUnit(for: type)
            )
        }

        // Create view models for each entity
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.graphViewModels = newChartEntities.map { entity in
                SensorGraphViewModel(graphEntity: entity, parentViewModel: self)
            }
        }
    }
    func insertMeasurements(
        _ newValues: [RuuviMeasurement],
        for sensor: RuuviTagSensor
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.updateMeasurements(newValues, for: sensor)
        }
    }
    func updateLatestRecord(
        _ record: RuuviTagSensorRecord,
        for sensor: RuuviTagSensor
    ) {

    }
    func interactorDidUpdate(
        sensor: AnyRuuviTagSensor
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.reloadCharts()
        }
    }

    func interactorDidError(
        _ error: RUError,
        for sensor: RuuviTagSensor
    ) {
        // Handle errors
        print("Error: \(error)")
    }

    // MARK: - Private Methods

    private func updateMeasurements(_ measurements: [RuuviMeasurement], for sensor: RuuviTagSensor) {
        // Process measurements into chart data
        for viewModel in graphViewModels {
            let type = viewModel.graphEntity.graphType
            let entries = processEntries(for: type, from: measurements)
            let dataSet = createDataSet(for: type, entries: entries)

            if !entries.isEmpty {
                let chartData = LineChartData(dataSet: dataSet)
                viewModel.updateChartData(with: chartData)
                viewModel.updateDataSet(with: [dataSet])
            }
        }

        // Signal data was updated
        isFirstEntry = false
        objectWillChange.send()
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func processEntries(for type: MeasurementType, from measurements: [RuuviMeasurement]) -> [ChartDataEntry] {
        return measurements.compactMap { measurement -> ChartDataEntry? in
            let x = measurement.date.timeIntervalSince1970
            switch type {
            case .temperature:
                guard let value = measurement.temperature else { return nil }
                return ChartDataEntry(x: x, y: value.value)
            case .humidity:
                guard let value = measurement.humidity else { return nil }
                return ChartDataEntry(x: x, y: value.value)
            case .pressure:
                guard let value = measurement.pressure else { return nil }
                return ChartDataEntry(x: x, y: value.value)
            case .aqi:
                guard let value = calculateAQI(from: measurement) else { return nil }
                return ChartDataEntry(x: x, y: value)
            case .co2:
                guard let value = measurement.co2 else { return nil }
                return ChartDataEntry(x: x, y: value)
            case .pm25:
                guard let value = measurement.pm2_5 else { return nil }
                return ChartDataEntry(x: x, y: value)
            case .pm10:
                guard let value = measurement.pm10 else { return nil }
                return ChartDataEntry(x: x, y: value)
            case .voc:
                guard let value = measurement.voc else { return nil }
                return ChartDataEntry(x: x, y: value)
            case .nox:
                guard let value = measurement.nox else { return nil }
                return ChartDataEntry(x: x, y: value)
            case .luminosity:
                guard let value = measurement.luminosity else { return nil }
                return ChartDataEntry(x: x, y: value)
            case .sound:
                guard let value = measurement.sound else { return nil }
                return ChartDataEntry(x: x, y: value)
            default:
                return nil
            }
        }.sorted { $0.x < $1.x }
    }

    private func createDataSet(for type: MeasurementType, entries: [ChartDataEntry]) -> LineChartDataSet {
        let dataSet = LineChartDataSet(entries: entries, label: type.rawValue)
        configureDataSet(dataSet, for: type)
        return dataSet
    }

    private func configureDataSet(_ dataSet: LineChartDataSet, for type: MeasurementType) {
        // Set appearance based on measurement type
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        dataSet.lineWidth = 2.0
        dataSet.mode = .cubicBezier

        // Colors based on measurement type
        switch type {
        case .temperature:
            dataSet.setColor(.systemRed)
        case .humidity:
            dataSet.setColor(.systemBlue)
        case .pressure:
            dataSet.setColor(.systemGreen)
        case .aqi:
            dataSet.setColor(.systemPurple)
        case .co2:
            dataSet.setColor(.systemOrange)
        case .pm25, .pm10:
            dataSet.setColor(.systemBrown)
        case .voc, .nox:
            dataSet.setColor(.systemYellow)
        case .luminosity:
            dataSet.setColor(.systemIndigo)
        case .sound:
            dataSet.setColor(.systemTeal)
        default:
            dataSet.setColor(.systemGray)
        }

        // Fill gradient if needed
        let gradientColors = [UIColor.systemGray.cgColor,
                              UIColor.clear.cgColor]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: nil)!
        dataSet.fillAlpha = 0.3
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
    }

//    // Helper methods for data conversion
//    private func getAlertValue(for type: MeasurementType, isUpper: Bool, sensor: AnyRuuviTagSensor) -> Double? {
//        // Get from interactor's sensor settings
//        guard let settings = (interactor as? NewCardsInteractor)?.sensorSettings else {
//            return nil
//        }
//
//        switch type {
//        case .temperature:
//            return isUpper ? settings.temperatureAlertMax : settings.temperatureAlertMin
//        case .humidity:
//            return isUpper ? settings.humidityAlertMax : settings.humidityAlertMin
//        case .pressure:
//            return isUpper ? settings.pressureAlertMax : settings.pressureAlertMin
//        case .co2:
//            return isUpper ? settings.co2AlertMax : settings.co2AlertMin
//        case .voc:
//            return isUpper ? settings.vocAlertMax : settings.vocAlertMin
//        case .pm25:
//            return isUpper ? settings.pm25AlertMax : settings.pm25AlertMin
//        case .pm10:
//            return isUpper ? settings.pm10AlertMax : settings.pm10AlertMin
//        case .nox:
//            return isUpper ? settings.noxAlertMax : settings.noxAlertMin
//        case .sound:
//            return isUpper ? settings.soundAlertMax : settings.soundAlertMin
//        case .luminosity:
//            return isUpper ? settings.lightAlertMax : settings.lightAlertMin
//        default:
//            return nil
//        }
//    }

    private func getMeasurementUnit(for type: MeasurementType) -> String {
        switch type {
        case .temperature:
            return "°C"
        case .humidity:
            return "%"
        case .pressure:
            return "hPa"
        case .co2:
            return "ppm"
        case .pm25, .pm10:
            return "μg/m³"
        case .voc, .nox:
            return "ppb"
        case .luminosity:
            return "lux"
        case .sound:
            return "dB"
        default:
            return ""
        }
    }

    private func calculateAQI(from measurement: RuuviMeasurement) -> Double? {
        // Simplified AQI calculation - implement your actual logic
        if let co2 = measurement.co2, let voc = measurement.voc {
            return (co2 / 10) + voc
        } else if let pm25 = measurement.pm2_5 {
            return pm25 * 4.0
        }
        return nil
    }
}
