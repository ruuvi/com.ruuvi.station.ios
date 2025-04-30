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

// swiftlint:disable file_length
import Foundation
import SwiftUI
import RuuviOntology
import Combine
import DGCharts
import RuuviService
import RuuviLocal
import RuuviLocalization

// swiftlint:disable:next type_body_length
class SensorGraphContainerViewModel: ObservableObject, NewCardsInteractorOutput {
    // UI coordination state
    @Published var activeSensor: RuuviTagSensor?

    // UI coordination state
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

    // Services and dependencies
    private let interactor: NewCardsInteractorInput
    let measurementService: RuuviServiceMeasurement
    private let settings: RuuviLocalSettings
    private let alertService: RuuviServiceAlert
    private let flags: RuuviLocalFlags

    // Data state
    private var graphData: [RuuviMeasurement] = []
    private var graphModules: [MeasurementType] = []
    private var graphDataSource: [SensorGraphEntity] = []
    private var sensorSettings: [SensorSettings] = []
    private var cancellables = Set<AnyCancellable>()

    private let coordinator: CardsCoordinator

    init(
        coordinator: CardsCoordinator,
        interactor: NewCardsInteractorInput
    ) {
        self.interactor = interactor
        self.coordinator = coordinator

        let r = AppAssembly.shared.assembler.resolver
        self.measurementService = r.resolve(RuuviServiceMeasurement.self)!
        self.settings = r.resolve(RuuviLocalSettings.self)!
        self.alertService = r.resolve(RuuviServiceAlert.self)!
        self.flags = r.resolve(RuuviLocalFlags.self)!
        self.chartDurationHours = settings.chartDurationHours

        // Connect to interactor
        (interactor as? NewCardsInteractor)?.presenter = self

        coordinator.activeSensorData
            .receive(on: RunLoop.main)
            .sink { [weak self] activeSensor in
                self?.activeSensor = activeSensor
                //                self?.onAppear()
                print("Active sensor: \(activeSensor?.name)")
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

    private func logChartDataState() {
        print("Graph data count: \(graphData.count)")
        print("Graph view models count: \(graphViewModels.count)")

        for (index, viewModel) in graphViewModels.enumerated() {
            let entryCount = (viewModel.graphEntity.graphData?.dataSets.first as? LineChartDataSet)?.entries.count ?? 0
            print("View model \(index) (\(viewModel.graphEntity.graphType)) has \(entryCount) entries")
        }
    }

    // MARK: User actions

    func onAppear() {
        if let activeSensor = activeSensor {
            print("SensorGraphContainerViewModel onAppear - configuring sensor: \(activeSensor.name ?? "unknown")")

            // Clear existing data first
            graphData = []
            graphDataSource = []

            // Configure the interactor with this sensor
            interactor.configure(withTag: activeSensor.any, andSettings: nil)

            // Ensure we restart data observation
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.interactor.restartObservingData()
            }
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
//        updateDataSet = true
//        interactor.restartObservingData()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
//            self?.updateDataSet = false
//        }
    }

    func stopObserving() {
        interactor.stopObservingRuuviTagsData()
//        clearAllCharts()
    }

    // MARK: - Helper Methods
    private func clearAllCharts() {
        // Clear arrays holding data
        graphData = []
        graphDataSource = []

        // Clear each chart view model's data
        for viewModel in graphViewModels {
            viewModel.graphEntity.graphData = nil
            viewModel.graphEntity.dataSet = []
            viewModel.objectWillChange.send()
        }

        // Signal the container view model has changed
        objectWillChange.send()
    }

    // MARK: - NewCardsInteractorOutput Implementation

    func createChartModules(from types: [MeasurementType], for sensor: RuuviTagSensor) {
        graphModules = types

        // Create chart entities for each measurement type
        let newChartEntities = types.map { type -> SensorGraphEntity in
            return SensorGraphEntity(
                ruuviTagId: sensor.id,
                graphType: type,
                dataSet: [],
                graphData: nil,
                upperAlertValue: getAlertValue(for: type, isUpper: true, sensor: sensor),
                lowerAlertValue: getAlertValue(for: type, isUpper: false, sensor: sensor),
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

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func insertMeasurements(_ newValues: [RuuviMeasurement], for sensor: RuuviTagSensor) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Process data for each measurement type
            var temperatureData: [ChartDataEntry] = []
            var humidityData: [ChartDataEntry] = []
            var pressureData: [ChartDataEntry] = []
            var aqiData: [ChartDataEntry] = []
            var co2Data: [ChartDataEntry] = []
            var pm25Data: [ChartDataEntry] = []
            var pm10Data: [ChartDataEntry] = []
            var vocData: [ChartDataEntry] = []
            var noxData: [ChartDataEntry] = []
            var luminosityData: [ChartDataEntry] = []
            var soundData: [ChartDataEntry] = []

            let sensorSettings = self.settingsForSensor(sensor)

            // Process each measurement
            for measurement in newValues {
                // Temperature
                if let entry = self.chartEntry(for: measurement, type: .temperature, sensorSettings: sensorSettings) {
                    temperatureData.append(entry)
                }

                // Humidity
                if let entry = self.chartEntry(for: measurement, type: .humidity, sensorSettings: sensorSettings) {
                    humidityData.append(entry)
                }

                // Pressure
                if let entry = self.chartEntry(for: measurement, type: .pressure, sensorSettings: sensorSettings) {
                    pressureData.append(entry)
                }

                // AQI
                if let entry = self.chartEntry(for: measurement, type: .aqi, sensorSettings: sensorSettings) {
                    aqiData.append(entry)
                }

                // CO2
                if let entry = self.chartEntry(for: measurement, type: .co2, sensorSettings: sensorSettings) {
                    co2Data.append(entry)
                }

                // PM2.5
                if let entry = self.chartEntry(for: measurement, type: .pm25, sensorSettings: sensorSettings) {
                    pm25Data.append(entry)
                }

                // PM10
                if let entry = self.chartEntry(for: measurement, type: .pm10, sensorSettings: sensorSettings) {
                    pm10Data.append(entry)
                }

                // VOC
                if let entry = self.chartEntry(for: measurement, type: .voc, sensorSettings: sensorSettings) {
                    vocData.append(entry)
                }

                // NOx
                if let entry = self.chartEntry(for: measurement, type: .nox, sensorSettings: sensorSettings) {
                    noxData.append(entry)
                }

                // Luminosity
                if let entry = self.chartEntry(for: measurement, type: .luminosity, sensorSettings: sensorSettings) {
                    luminosityData.append(entry)
                }

                // Sound
                if let entry = self.chartEntry(for: measurement, type: .sound, sensorSettings: sensorSettings) {
                    soundData.append(entry)
                }
            }

            // Update each chart view model with new data
            for viewModel in self.graphViewModels {
                let type = viewModel.graphEntity.graphType
                var entries: [ChartDataEntry] = []

                switch type {
                case .temperature: entries = temperatureData
                case .humidity: entries = humidityData
                case .pressure: entries = pressureData
                case .aqi: entries = aqiData
                case .co2: entries = co2Data
                case .pm25: entries = pm25Data
                case .pm10: entries = pm10Data
                case .voc: entries = vocData
                case .nox: entries = noxData
                case .luminosity: entries = luminosityData
                case .sound: entries = soundData
                default: break
                }

                if !entries.isEmpty {
                    let dataSet = self.createDataSet(
                        for: type,
                        entries: entries,
                        ruuviTagSensor: sensor
                    )
                    let chartData = LineChartData(dataSet: dataSet)

                    // Draw circles if needed
                    self.drawCirclesIfNeeded(for: chartData, entriesCount: entries.count)

                    viewModel.updateChartData(with: chartData)
                    viewModel.updateDataSet(with: [dataSet])
                    print("Updated chart data for \(type) with \(entries.count) entries")
                }
            }

            // Signal data was updated
            self.isFirstEntry = newValues.count == 1
            self.objectWillChange.send()
        }
    }

    func updateLatestRecord(_ record: RuuviTagSensorRecord, for sensor: RuuviTagSensor) {
        // Can be used for displaying the latest measurement in the UI if needed
    }

    func interactorDidUpdate(sensor: RuuviTagSensor) {
        if let interactor = interactor as? NewCardsInteractor {
            self.graphData = interactor.ruuviTagData
        }

        print("Sensor updated: \(sensor.name) count: \(graphData.count)")

        // Only call createChartData if we have data to display
        if !graphData.isEmpty {
            createChartData(for: sensor)
        } else {
            print("Warning: No data available for \(sensor.name)")

            // Try to trigger a cloud sync if no data is available
            if let interactor = interactor as? NewCardsInteractor {
                interactor.ensureDataAvailable()
            }
        }
    }

    func interactorDidError(_ error: RUError, for sensor: RuuviTagSensor) {
        // Handle errors, possibly by showing an alert or logging
        print("Error: \(error)")
    }

    // MARK: - Private Methods

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func createChartData(for sensor: RuuviTagSensor) {
        print("Creating chart data for sensor: \(sensor.name)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.graphDataSource.removeAll()

            // Process data for each measurement type
            var temperatureData: [ChartDataEntry] = []
            var humidityData: [ChartDataEntry] = []
            var pressureData: [ChartDataEntry] = []
            var aqiData: [ChartDataEntry] = []
            var co2Data: [ChartDataEntry] = []
            var pm25Data: [ChartDataEntry] = []
            var pm10Data: [ChartDataEntry] = []
            var vocData: [ChartDataEntry] = []
            var noxData: [ChartDataEntry] = []
            var luminosityData: [ChartDataEntry] = []
            var soundData: [ChartDataEntry] = []

            let sensorSettings = self.settingsForSensor(sensor)

            // Process each measurement to create chart entries
            for measurement in self.graphData {
                // Temperature
                if let entry = self.chartEntry(for: measurement, type: .temperature, sensorSettings: sensorSettings) {
                    temperatureData.append(entry)
                }

                // Humidity
                if let entry = self.chartEntry(for: measurement, type: .humidity, sensorSettings: sensorSettings) {
                    humidityData.append(entry)
                }

                // Pressure
                if let entry = self.chartEntry(for: measurement, type: .pressure, sensorSettings: sensorSettings) {
                    pressureData.append(entry)
                }

                // AQI
                if let entry = self.chartEntry(for: measurement, type: .aqi, sensorSettings: sensorSettings) {
                    aqiData.append(entry)
                }

                // CO2
                if let entry = self.chartEntry(for: measurement, type: .co2, sensorSettings: sensorSettings) {
                    co2Data.append(entry)
                }

                // PM2.5
                if let entry = self.chartEntry(for: measurement, type: .pm25, sensorSettings: sensorSettings) {
                    pm25Data.append(entry)
                }

                // PM10
                if let entry = self.chartEntry(for: measurement, type: .pm10, sensorSettings: sensorSettings) {
                    pm10Data.append(entry)
                }

                // VOC
                if let entry = self.chartEntry(for: measurement, type: .voc, sensorSettings: sensorSettings) {
                    vocData.append(entry)
                }

                // NOx
                if let entry = self.chartEntry(for: measurement, type: .nox, sensorSettings: sensorSettings) {
                    noxData.append(entry)
                }

                // Luminosity
                if let entry = self.chartEntry(for: measurement, type: .luminosity, sensorSettings: sensorSettings) {
                    luminosityData.append(entry)
                }

                // Sound
                if let entry = self.chartEntry(for: measurement, type: .sound, sensorSettings: sensorSettings) {
                    soundData.append(entry)
                }
            }

            // Create data sets for each measurement type with entries

            // Temperature chart
            if !temperatureData.isEmpty {
                let isOn = self.alertService.isOn(type: .temperature(lower: 0, upper: 0), for: sensor)
                let upperAlert = isOn ? self.alertService.upperCelsius(for: sensor)
                    .flatMap { Temperature($0, unit: .celsius) }
                    .map { self.measurementService.double(for: $0) } : nil
                let lowerAlert = isOn ? self.alertService.lowerCelsius(for: sensor)
                    .flatMap { Temperature($0, unit: .celsius) }
                    .map { self.measurementService.double(for: $0) } : nil

                let temperatureDataSet = TagChartsHelper.newDataSet(
                    upperAlertValue: upperAlert,
                    entries: temperatureData,
                    lowerAlertValue: lowerAlert,
                    showAlertRangeInGraph: self.flags.showAlertsRangeInGraph
                )
                let chartData = LineChartData(dataSet: temperatureDataSet)
                self.drawCirclesIfNeeded(for: chartData, entriesCount: temperatureData.count)

                let temperatureChartData = SensorGraphEntity(
                    ruuviTagId: sensor.id,
                    graphType: .temperature,
                    dataSet: [],
                    graphData: chartData,
                    upperAlertValue: upperAlert,
                    lowerAlertValue: lowerAlert,
                    unit: self.measurementService.units.temperatureUnit.symbol
                )
                self.graphDataSource.append(temperatureChartData)
            }

            // Humidity chart
            if !humidityData.isEmpty {
                let isOn = self.alertService.isOn(type: .relativeHumidity(lower: 0, upper: 0), for: sensor)
                let isRelative = self.measurementService.units.humidityUnit == .percent
                let upperAlert = (isOn && isRelative) ? self.alertService.upperRelativeHumidity(for: sensor).map { $0 * 100 } : nil
                let lowerAlert = (isOn && isRelative) ? self.alertService.lowerRelativeHumidity(for: sensor).map { $0 * 100 } : nil

                let humidityDataSet = TagChartsHelper.newDataSet(
                    upperAlertValue: upperAlert,
                    entries: humidityData,
                    lowerAlertValue: lowerAlert,
                    showAlertRangeInGraph: self.flags.showAlertsRangeInGraph
                )
                let chartData = LineChartData(dataSet: humidityDataSet)
                self.drawCirclesIfNeeded(for: chartData, entriesCount: humidityData.count)

                let humidityChartData = SensorGraphEntity(
                    ruuviTagId: sensor.id,
                    graphType: .humidity,
                    dataSet: [],
                    graphData: chartData,
                    upperAlertValue: upperAlert,
                    lowerAlertValue: lowerAlert,
                    unit: self.measurementService.units.humidityUnit.symbol
                )
                self.graphDataSource.append(humidityChartData)
            }

            // Pressure chart
            if !pressureData.isEmpty {
                let isOn = self.alertService.isOn(type: .pressure(lower: 0, upper: 0), for: sensor)
                let upperAlert = isOn ? self.alertService.upperPressure(for: sensor)
                    .flatMap { Pressure($0, unit: .hectopascals) }
                    .map { self.measurementService.double(for: $0) } : nil
                let lowerAlert = isOn ? self.alertService.lowerPressure(for: sensor)
                    .flatMap { Pressure($0, unit: .hectopascals) }
                    .map { self.measurementService.double(for: $0) } : nil

                let pressureDataSet = TagChartsHelper.newDataSet(
                    upperAlertValue: upperAlert,
                    entries: pressureData,
                    lowerAlertValue: lowerAlert,
                    showAlertRangeInGraph: self.flags.showAlertsRangeInGraph
                )
                let chartData = LineChartData(dataSet: pressureDataSet)
                self.drawCirclesIfNeeded(for: chartData, entriesCount: pressureData.count)

                let pressureChartData = SensorGraphEntity(
                    ruuviTagId: sensor.id,
                    graphType: .pressure,
                    dataSet: [],
                    graphData: chartData,
                    upperAlertValue: upperAlert,
                    lowerAlertValue: lowerAlert,
                    unit: self.measurementService.units.pressureUnit.symbol
                )
                self.graphDataSource.append(pressureChartData)
            }

            // AQI chart
            if !aqiData.isEmpty {
                let aqiDataSet = TagChartsHelper.newDataSet(
                    upperAlertValue: nil,
                    entries: aqiData,
                    lowerAlertValue: nil,
                    showAlertRangeInGraph: self.flags.showAlertsRangeInGraph
                )
                let chartData = LineChartData(dataSet: aqiDataSet)
                self.drawCirclesIfNeeded(for: chartData, entriesCount: aqiData.count)

                let aqiChartData = SensorGraphEntity(
                    ruuviTagId: sensor.id,
                    graphType: .aqi,
                    dataSet: [],
                    graphData: chartData,
                    upperAlertValue: nil,
                    lowerAlertValue: nil,
                    unit: RuuviLocalization.aqi
                )
                self.graphDataSource.append(aqiChartData)
            }

            // CO2 chart
            if !co2Data.isEmpty {
                let isOn = self.alertService.isOn(type: .carbonDioxide(lower: 0, upper: 0), for: sensor)
                let upperAlert = isOn ? self.alertService.upperCarbonDioxide(for: sensor).map { $0 } : nil
                let lowerAlert = isOn ? self.alertService.lowerCarbonDioxide(for: sensor).map { $0 } : nil

                let co2DataSet = TagChartsHelper.newDataSet(
                    upperAlertValue: upperAlert,
                    entries: co2Data,
                    lowerAlertValue: lowerAlert,
                    showAlertRangeInGraph: self.flags.showAlertsRangeInGraph
                )
                let chartData = LineChartData(dataSet: co2DataSet)
                self.drawCirclesIfNeeded(for: chartData, entriesCount: co2Data.count)

                let co2ChartData = SensorGraphEntity(
                    ruuviTagId: sensor.id,
                    graphType: .co2,
                    dataSet: [],
                    graphData: chartData,
                    upperAlertValue: upperAlert,
                    lowerAlertValue: lowerAlert,
                    unit: RuuviLocalization.unitCo2
                )
                self.graphDataSource.append(co2ChartData)
            }

            // PM10 chart
            if !pm10Data.isEmpty {
                let isOn = self.alertService.isOn(type: .pMatter10(lower: 0, upper: 0), for: sensor)
                let upperAlert = isOn ? self.alertService.upperPM10(for: sensor).map { $0 } : nil
                let lowerAlert = isOn ? self.alertService.lowerPM10(for: sensor).map { $0 } : nil

                let pm10DataSet = TagChartsHelper.newDataSet(
                    upperAlertValue: upperAlert,
                    entries: pm10Data,
                    lowerAlertValue: lowerAlert,
                    showAlertRangeInGraph: self.flags.showAlertsRangeInGraph
                )
                let chartData = LineChartData(dataSet: pm10DataSet)
                self.drawCirclesIfNeeded(for: chartData, entriesCount: pm10Data.count)

                let pm10ChartData = SensorGraphEntity(
                    ruuviTagId: sensor.id,
                    graphType: .pm10,
                    dataSet: [],
                    graphData: chartData,
                    upperAlertValue: upperAlert,
                    lowerAlertValue: lowerAlert,
                    unit: RuuviLocalization.unitPm10
                )
                self.graphDataSource.append(pm10ChartData)
            }

            // PM2.5 chart
            if !pm25Data.isEmpty {
                let isOn = self.alertService.isOn(type: .pMatter2_5(lower: 0, upper: 0), for: sensor)
                let upperAlert = isOn ? self.alertService.upperPM2_5(for: sensor).map { $0 } : nil
                let lowerAlert = isOn ? self.alertService.lowerPM2_5(for: sensor).map { $0 } : nil

                let pm25DataSet = TagChartsHelper.newDataSet(
                    upperAlertValue: upperAlert,
                    entries: pm25Data,
                    lowerAlertValue: lowerAlert,
                    showAlertRangeInGraph: self.flags.showAlertsRangeInGraph
                )
                let chartData = LineChartData(dataSet: pm25DataSet)
                self.drawCirclesIfNeeded(for: chartData, entriesCount: pm25Data.count)

                let pm25ChartData = SensorGraphEntity(
                    ruuviTagId: sensor.id,
                    graphType: .pm25,
                    dataSet: [],
                    graphData: chartData,
                    upperAlertValue: upperAlert,
                    lowerAlertValue: lowerAlert,
                    unit: RuuviLocalization.unitPm25
                )
                self.graphDataSource.append(pm25ChartData)
            }

            // VOC chart
            if !vocData.isEmpty {
                let isOn = self.alertService.isOn(type: .voc(lower: 0, upper: 0), for: sensor)
                let upperAlert = isOn ? self.alertService.upperVOC(for: sensor).map { $0 } : nil
                let lowerAlert = isOn ? self.alertService.lowerVOC(for: sensor).map { $0 } : nil

                let vocDataSet = TagChartsHelper.newDataSet(
                    upperAlertValue: upperAlert,
                    entries: vocData,
                    lowerAlertValue: lowerAlert,
                    showAlertRangeInGraph: self.flags.showAlertsRangeInGraph
                )
                let chartData = LineChartData(dataSet: vocDataSet)
                self.drawCirclesIfNeeded(for: chartData, entriesCount: vocData.count)

                let vocChartData = SensorGraphEntity(
                    ruuviTagId: sensor.id,
                    graphType: .voc,
                    dataSet: [],
                    graphData: chartData,
                    upperAlertValue: upperAlert,
                    lowerAlertValue: lowerAlert,
                    unit: RuuviLocalization.unitVoc
                )
                self.graphDataSource.append(vocChartData)
            }

            // NOx chart
            if !noxData.isEmpty {
                let isOn = self.alertService.isOn(type: .nox(lower: 0, upper: 0), for: sensor)
                let upperAlert = isOn ? self.alertService.upperNOX(for: sensor).map { $0 } : nil
                let lowerAlert = isOn ? self.alertService.lowerNOX(for: sensor).map { $0 } : nil

                let noxDataSet = TagChartsHelper.newDataSet(
                    upperAlertValue: upperAlert,
                    entries: noxData,
                    lowerAlertValue: lowerAlert,
                    showAlertRangeInGraph: self.flags.showAlertsRangeInGraph
                )
                let chartData = LineChartData(dataSet: noxDataSet)
                self.drawCirclesIfNeeded(for: chartData, entriesCount: noxData.count)

                let noxChartData = SensorGraphEntity(
                    ruuviTagId: sensor.id,
                    graphType: .nox,
                    dataSet: [],
                    graphData: chartData,
                    upperAlertValue: upperAlert,
                    lowerAlertValue: lowerAlert,
                    unit: RuuviLocalization.unitNox
                )
                self.graphDataSource.append(noxChartData)
            }

            // Luminosity chart
            if !luminosityData.isEmpty {
                let isOn = self.alertService.isOn(type: .luminosity(lower: 0, upper: 0), for: sensor)
                let upperAlert = isOn ? self.alertService.upperLuminosity(for: sensor).map { $0 } : nil
                let lowerAlert = isOn ? self.alertService.lowerLuminosity(for: sensor).map { $0 } : nil

                let luminosityDataSet = TagChartsHelper.newDataSet(
                    upperAlertValue: upperAlert,
                    entries: luminosityData,
                    lowerAlertValue: lowerAlert,
                    showAlertRangeInGraph: self.flags.showAlertsRangeInGraph
                )
                let chartData = LineChartData(dataSet: luminosityDataSet)
                self.drawCirclesIfNeeded(for: chartData, entriesCount: luminosityData.count)

                let luminosityChartData = SensorGraphEntity(
                    ruuviTagId: sensor.id,
                    graphType: .luminosity,
                    dataSet: [],
                    graphData: chartData,
                    upperAlertValue: upperAlert,
                    lowerAlertValue: lowerAlert,
                    unit: RuuviLocalization.unitLuminosity
                )
                self.graphDataSource.append(luminosityChartData)
            }

            // Sound chart
            if !soundData.isEmpty {
                let isOn = self.alertService.isOn(type: .sound(lower: 0, upper: 0), for: sensor)
                let upperAlert = isOn ? self.alertService.upperSound(for: sensor).map { $0 } : nil
                let lowerAlert = isOn ? self.alertService.lowerSound(for: sensor).map { $0 } : nil

                let soundDataSet = TagChartsHelper.newDataSet(
                    upperAlertValue: upperAlert,
                    entries: soundData,
                    lowerAlertValue: lowerAlert,
                    showAlertRangeInGraph: self.flags.showAlertsRangeInGraph
                )
                let chartData = LineChartData(dataSet: soundDataSet)
                self.drawCirclesIfNeeded(for: chartData, entriesCount: soundData.count)

                let soundChartData = SensorGraphEntity(
                    ruuviTagId: sensor.id,
                    graphType: .sound,
                    dataSet: [],
                    graphData: chartData,
                    upperAlertValue: upperAlert,
                    lowerAlertValue: lowerAlert,
                    unit: RuuviLocalization.unitSound
                )
                self.graphDataSource.append(soundChartData)
            }

            // Update view models with the new data
            self.updateViewModelsFromDataSource(sensor: sensor)
        }
    }

    private func updateViewModelsFromDataSource(sensor: RuuviTagSensor) {
        print("Updating view models from data source with \(graphDataSource.count) sources")

        // If we don't have view models yet, create them
        if graphViewModels.isEmpty {
            graphViewModels = graphDataSource.map { entity in
                return SensorGraphViewModel(graphEntity: entity, parentViewModel: self)
            }
            print("Created \(graphViewModels.count) new view models")
        } else {
            // Update existing view models
            for (index, dataSource) in graphDataSource.enumerated() {
                let viewModelExists = graphViewModels.contains { $0.graphEntity.graphType == dataSource.graphType }

                if viewModelExists {
                    // Update existing view model
                    if let vmIndex = graphViewModels.firstIndex(where: { $0.graphEntity.graphType == dataSource.graphType }) {
                        graphViewModels[vmIndex].graphEntity.graphData = dataSource.graphData
                        graphViewModels[vmIndex].graphEntity.upperAlertValue = dataSource.upperAlertValue
                        graphViewModels[vmIndex].graphEntity.lowerAlertValue = dataSource.lowerAlertValue

                        // Create data set array if needed
                        if let lineDataSet = dataSource.graphData?.dataSets.first as? LineChartDataSet {
                            graphViewModels[vmIndex].graphEntity.dataSet = [lineDataSet]
                        }

                        // Log what we're updating
                        let entryCount = (dataSource.graphData?.dataSets.first as? LineChartDataSet)?.entries.count ?? 0
                        print("Updated view model for \(dataSource.graphType) with \(entryCount) entries")

                        graphViewModels[vmIndex].objectWillChange.send()
                    }
                } else {
                    // Create a new view model for this data source
                    let newViewModel = SensorGraphViewModel(graphEntity: dataSource, parentViewModel: self)
                    graphViewModels.append(newViewModel)
                    print("Added new view model for \(dataSource.graphType)")
                }
            }
        }

        // Log the state after update
        logChartDataState()

        // Signal the overall view model has changed
        objectWillChange.send()
    }

    private func drawCirclesIfNeeded(for chartData: LineChartData?, entriesCount: Int? = nil) {
        if let dataSet = chartData?.dataSets.first as? LineChartDataSet {
            let count: Int = entriesCount ?? dataSet.entries.count
            switch count {
            case 1:
                dataSet.circleRadius = 6
                dataSet.drawCirclesEnabled = true
            default:
                dataSet.circleRadius = 0.8
                dataSet.drawCirclesEnabled = settings.chartDrawDotsOn
            }
        }
    }

    private func createDataSet(for type: MeasurementType, entries: [ChartDataEntry], ruuviTagSensor: RuuviTagSensor) -> LineChartDataSet {

        var upperAlert: Double? = nil
        var lowerAlert: Double? = nil

        // Get alert values based on type
        switch type {
        case .temperature:
            let isOn = alertService.isOn(type: .temperature(lower: 0, upper: 0), for: ruuviTagSensor)
            upperAlert = isOn ? alertService.upperCelsius(for: ruuviTagSensor)
                .flatMap { Temperature($0, unit: .celsius) }
                .map { measurementService.double(for: $0) } : nil
            lowerAlert = isOn ? alertService.lowerCelsius(for: ruuviTagSensor)
                .flatMap { Temperature($0, unit: .celsius) }
                .map { measurementService.double(for: $0) } : nil

        case .humidity:
            let isOn = alertService.isOn(type: .relativeHumidity(lower: 0, upper: 0), for: ruuviTagSensor)
            let isRelative = measurementService.units.humidityUnit == .percent
            upperAlert = (isOn && isRelative) ? alertService.upperRelativeHumidity(for: ruuviTagSensor).map { $0 * 100 } : nil
            lowerAlert = (isOn && isRelative) ? alertService.lowerRelativeHumidity(for: ruuviTagSensor).map { $0 * 100 } : nil

        case .pressure:
            let isOn = alertService.isOn(type: .pressure(lower: 0, upper: 0), for: ruuviTagSensor)
            upperAlert = isOn ? alertService.upperPressure(for: ruuviTagSensor)
                .flatMap { Pressure($0, unit: .hectopascals) }
                .map { measurementService.double(for: $0) } : nil
            lowerAlert = isOn ? alertService.lowerPressure(for: ruuviTagSensor)
                .flatMap { Pressure($0, unit: .hectopascals) }
                .map { measurementService.double(for: $0) } : nil

        case .co2:
            let isOn = alertService.isOn(type: .carbonDioxide(lower: 0, upper: 0), for: ruuviTagSensor)
            upperAlert = isOn ? alertService.upperCarbonDioxide(for: ruuviTagSensor).map { $0 } : nil
            lowerAlert = isOn ? alertService.lowerCarbonDioxide(for: ruuviTagSensor).map { $0 } : nil

        case .pm25:
            let isOn = alertService.isOn(type: .pMatter2_5(lower: 0, upper: 0), for: ruuviTagSensor)
            upperAlert = isOn ? alertService.upperPM2_5(for: ruuviTagSensor).map { $0 } : nil
            lowerAlert = isOn ? alertService.lowerPM2_5(for: ruuviTagSensor).map { $0 } : nil

        case .pm10:
            let isOn = alertService.isOn(type: .pMatter10(lower: 0, upper: 0), for: ruuviTagSensor)
            upperAlert = isOn ? alertService.upperPM10(for: ruuviTagSensor).map { $0 } : nil
            lowerAlert = isOn ? alertService.lowerPM10(for: ruuviTagSensor).map { $0 } : nil

        case .voc:
            let isOn = alertService.isOn(type: .voc(lower: 0, upper: 0), for: ruuviTagSensor)
            upperAlert = isOn ? alertService.upperVOC(for: ruuviTagSensor).map { $0 } : nil
            lowerAlert = isOn ? alertService.lowerVOC(for: ruuviTagSensor).map { $0 } : nil

        case .nox:
            let isOn = alertService.isOn(type: .nox(lower: 0, upper: 0), for: ruuviTagSensor)
            upperAlert = isOn ? alertService.upperNOX(for: ruuviTagSensor).map { $0 } : nil
            lowerAlert = isOn ? alertService.lowerNOX(for: ruuviTagSensor).map { $0 } : nil

        case .luminosity:
            let isOn = alertService.isOn(type: .luminosity(lower: 0, upper: 0), for: ruuviTagSensor)
            upperAlert = isOn ? alertService.upperLuminosity(for: ruuviTagSensor).map { $0 } : nil
            lowerAlert = isOn ? alertService.lowerLuminosity(for: ruuviTagSensor).map { $0 } : nil

        case .sound:
            let isOn = alertService.isOn(type: .sound(lower: 0, upper: 0), for: ruuviTagSensor)
            upperAlert = isOn ? alertService.upperSound(for: ruuviTagSensor).map { $0 } : nil
            lowerAlert = isOn ? alertService.lowerSound(for: ruuviTagSensor).map { $0 } : nil

        default:
            break
        }

        // Create the data set with alerts
        let dataSet = TagChartsHelper.newDataSet(
            upperAlertValue: upperAlert,
            entries: entries,
            lowerAlertValue: lowerAlert,
            showAlertRangeInGraph: flags.showAlertsRangeInGraph
        )

        // Apply configuration based on type (color, etc)
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
        let gradientColors = [UIColor.green.cgColor,
                              UIColor.clear.cgColor]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: nil)!
        dataSet.fillAlpha = 0.3
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
    }

    // Helper methods for data conversion
    private func getAlertValue(for type: MeasurementType, isUpper: Bool, sensor: RuuviTagSensor) -> Double? {
        switch type {
        case .temperature:
            let isOn = alertService.isOn(type: .temperature(lower: 0, upper: 0), for: sensor)
            if isUpper {
                return isOn ? alertService.upperCelsius(for: sensor)
                    .flatMap { Temperature($0, unit: .celsius) }
                    .map { measurementService.double(for: $0) } : nil
            } else {
                return isOn ? alertService.lowerCelsius(for: sensor)
                    .flatMap { Temperature($0, unit: .celsius) }
                    .map { measurementService.double(for: $0) } : nil
            }

        case .humidity:
            let isOn = alertService.isOn(type: .relativeHumidity(lower: 0, upper: 0), for: sensor)
            let isRelative = measurementService.units.humidityUnit == .percent
            if isUpper {
                return (isOn && isRelative) ? alertService.upperRelativeHumidity(for: sensor).map { $0 * 100 } : nil
            } else {
                return (isOn && isRelative) ? alertService.lowerRelativeHumidity(for: sensor).map { $0 * 100 } : nil
            }

        case .pressure:
            let isOn = alertService.isOn(type: .pressure(lower: 0, upper: 0), for: sensor)
            if isUpper {
                return isOn ? alertService.upperPressure(for: sensor)
                    .flatMap { Pressure($0, unit: .hectopascals) }
                    .map { measurementService.double(for: $0) } : nil
            } else {
                return isOn ? alertService.lowerPressure(for: sensor)
                    .flatMap { Pressure($0, unit: .hectopascals) }
                    .map { measurementService.double(for: $0) } : nil
            }

            // Add other cases for other measurement types

        default:
            return nil
        }
    }

    private func getMeasurementUnit(for type: MeasurementType) -> String {
        switch type {
        case .temperature:
            return measurementService.units.temperatureUnit == .celsius ? "°C" : "°F"
        case .humidity:
            return measurementService.units.humidityUnit == .percent ? "%" : "g/m³"
        case .pressure:
            switch measurementService.units.pressureUnit {
            case .hectopascals: return "hPa"
            case .inchesOfMercury: return "inHg"
            case .millimetersOfMercury: return "mmHg"
            default:
                return ""
            }
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func chartEntry(
        for data: RuuviMeasurement,
        type: MeasurementType,
        sensorSettings: SensorSettings?
    ) -> ChartDataEntry? {
        var value: Double?
        switch type {
        case .temperature:
            let temp: Temperature?
            // Backward compatibility for the users who used earlier versions than 0.7.7
            // 1: If local record has temperature offset added, calculate and get original temp data
            // 2: Apply current sensor settings
            = if let offset = data.temperatureOffset, offset != 0 {
                data.temperature?
                    .minus(value: offset)?
                    .plus(sensorSettings: sensorSettings)
            } else {
                data.temperature?.plus(sensorSettings: sensorSettings)
            }
            value = measurementService.double(for: temp) ?? 0
        case .humidity:
            let humidity: Humidity?
            // Backward compatibility for the users who used earlier versions than 0.7.7
            // 1: If local record has humidity offset added, calculate and get original humidity data
            // 2: Apply current sensor settings
            = if let offset = data.humidityOffset, offset != 0 {
                data.humidity?
                    .minus(value: offset)?
                    .plus(sensorSettings: sensorSettings)
            } else {
                data.humidity?.plus(sensorSettings: sensorSettings)
            }
            value = measurementService.double(
                for: humidity,
                temperature: data.temperature,
                isDecimal: false
            )
        case .pressure:
            let pressure: Pressure?
            // Backward compatibility for the users who used earlier versions than 0.7.7
            // 1: If local record has pressure offset added, calculate and get original pressure data
            // 2: Apply current sensor settings
            = if let offset = data.pressureOffset, offset != 0 {
                data.pressure?
                    .minus(value: offset)?
                    .plus(sensorSettings: sensorSettings)
            } else {
                data.pressure?.plus(sensorSettings: sensorSettings)
            }
            value = measurementService.double(for: pressure)
        case .aqi:
            let (aqi, _, _) = measurementService.aqiString(
                for: data.co2,
                pm25: data.pm2_5,
                voc: data.voc,
                nox: data.nox
            )
            value = Double(aqi)
        case .co2:
            value = data.co2
        case .pm25:
            value = data.pm2_5
        case .pm10:
            value = data.pm10
        case .voc:
            value = data.voc
        case .nox:
            value = data.nox
        case .luminosity:
            value = data.luminosity
        case .sound:
            value = data.sound
        default:
            return nil
        }

        guard let y = value else {
            return nil
        }
        return ChartDataEntry(x: data.date.timeIntervalSince1970, y: y)
    }

    private func settingsForSensor(_ sensor: RuuviTagSensor) -> SensorSettings? {
        if let sensorSettings = self.sensorSettings
            .first(where: {
                ($0.luid?.any != nil && $0.luid?.any == sensor.luid?.any)
                || ($0.macId?.any != nil && $0.macId?.any == sensor.macId?.any)
            }) {
            return sensorSettings
        }
        return (interactor as? NewCardsInteractor)?.sensorSettings
    }
}
// swiftlint:enable file_length
