//import Combine
//import Foundation
//import RuuviOntology
//import RuuviReactor
//import RuuviService
//import RuuviStorage
//import BTKit
//import UIKit
//
//@MainActor
//class TagChartsInteractor: ObservableObject {
//
//    // MARK: - Published outputs for the ViewModel
//    @Published var latestMeasurement: RuuviMeasurement?
//    @Published var backgroundImage: UIImage?
//    @Published var chartDataSets: [TagChartViewData] = []
//    @Published var chartModules: [MeasurementType] = []
//    @Published var alertState: AlertState = .empty
//    @Published var isConnected: Bool = false
//    @Published var isConnectable: Bool = false
//
//    // The raw array of RuuviMeasurements
//    private var allMeasurements: [RuuviMeasurement] = []
//
//    // MARK: - Dependencies
//
//    private let ruuviReactor: RuuviReactor
//    private let ruuviStorage: RuuviStorage
//    private let measurementService: RuuviServiceMeasurement
//    private let alertService: RuuviServiceAlert
//    private let gattService: GATTService
//    private let sensorPropertiesService: RuuviServiceSensorProperties
//    private let background: BTBackground
//    private var tokens: [AnyCancellable] = []
//
//    // The sensor we manage
//    private var sensor: AnyRuuviTagSensor?
//
//    // MARK: - Init
//
//    init(
//        ruuviReactor: RuuviReactor,
//        ruuviStorage: RuuviStorage,
//        measurementService: RuuviServiceMeasurement,
//        alertService: RuuviServiceAlert,
//        gattService: GATTService,
//        sensorPropertiesService: RuuviServiceSensorProperties,
//        background: BTBackground
//    ) {
//        self.ruuviReactor = ruuviReactor
//        self.ruuviStorage = ruuviStorage
//        self.measurementService = measurementService
//        self.alertService = alertService
//        self.gattService = gattService
//        self.sensorPropertiesService = sensorPropertiesService
//        self.background = background
//    }
//
//    // MARK: - Configuration
//
//    func configureSensor(_ sensor: AnyRuuviTagSensor) {
//        self.sensor = sensor
//        loadSensorBackground(sensor)
//        updateAlertState(sensor)
//        isConnectable = sensor.isConnectable
//        isConnected = sensor.luid.map { background.isConnected(uuid: $0.value) } ?? false
//
//        // fetch initial chart modules, measurements, etc.
//        Task.detached(priority: .background) {
//            await self.reloadFromStorage()
//            await self.fetchLatest()
//            await self.determineChartModules()
//        }
//    }
//
//    func startObservers() {
//        // Start periodic or reactive observations from RuuviReactor if needed
//        // In a Combine-friendly approach, we might do something like:
////        guard let sensor = sensor else { return }
////        // Example observation
////        ruuviReactor.observeSensor(sensor)
////            .receive(on: DispatchQueue.global(qos: .background))
////            .sink { [weak self] change in
////                guard let self = self else { return }
////                switch change {
////                case let .update(updatedSensor):
////                    Task {
////                        await self.handleSensorUpdate(updatedSensor)
////                    }
////                // handle other reactor events...
////                default:
////                    break
////                }
////            }
////            .store(in: &tokens)
//    }
//
//    func stopObservers() {
//        tokens.forEach { $0.cancel() }
//        tokens.removeAll()
//    }
//
//    // MARK: - GATT Sync
//
//    func syncRecords(
//        progress: @escaping (BTServiceProgress) -> Void
//    ) async throws {
//        guard let sensor = sensor,
//              let luid = sensor.luid
//        else { return }
//
//        // Start an async GATT sync
//        try await withCheckedThrowingContinuation { continuation in
//            let op = gattService.syncLogs(
//                uuid: luid.value,
//                mac: sensor.macId?.value,
//                firmware: sensor.version,
//                from: /* sync date, e.g. last sync date? */ Date.distantPast,
//                settings: nil,
//                progress: { p in progress(p) },
//                connectionTimeout: 30,
//                serviceTimeout: 30
//            )
//            op.on(success: { _ in
//                continuation.resume(returning: ())
//            }, failure: { error in
//                continuation.resume(throwing: error)
//            })
//        }
//
//        // Once sync is done, refresh local DB
//        await reloadFromStorage()
//    }
//
//    func stopSyncRecords() async throws -> Bool {
//        guard let sensor = sensor, let luid = sensor.luid else { return false }
//        return try await withCheckedThrowingContinuation { continuation in
//            let op = gattService.stopGattSync(for: luid.value)
//            op.on(success: { didStop in
//                continuation.resume(returning: didStop)
//            }, failure: { error in
//                continuation.resume(throwing: error)
//            })
//        }
//    }
//
//    // MARK: - Private
//
//    private func handleSensorUpdate(_ updatedSensor: AnyRuuviTagSensor) async {
//        sensor = updatedSensor
//        isConnectable = updatedSensor.isConnectable
//        if let luid = updatedSensor.luid {
//            isConnected = background.isConnected(uuid: luid.value)
//        }
//        // Possibly re-fetch from DB if needed
//        await reloadFromStorage()
//        updateAlertState(updatedSensor)
//    }
//
//    private func updateAlertState(_ sensor: AnyRuuviTagSensor) {
//        if alertService.hasRegistrations(for: sensor) {
//            alertState = .registered
//        } else {
//            alertState = .empty
//        }
//    }
//
//    private func fetchLatest() async {
//        guard let sensor = sensor else { return }
//        do {
//            if let latest = try await ruuviStorage.readLatest(sensor) {
//                await MainActor.run {
//                    self.latestMeasurement = latest.value??
//                }
//            }
//        } catch {
//            // handle error
//        }
//    }
//
//    private func reloadFromStorage() async {
//        guard let sensor = sensor else { return }
//        do {
//            // For example, read data from the last X hours
//            let fromDate = Calendar.autoupdatingCurrent.date(
//                byAdding: .hour,
//                value: -240,  // 10 days worth of data, for example
//                to: Date()
//            ) ?? .distantPast
//
//            let measurements = try await ruuviStorage
//                .read(sensor.id, after: fromDate, with: 2)
//                .asyncValue()
//                .map(\.measurement)
//
//            // Now we can recalc chart data
//            await self.updateMeasurements(measurements)
//
//        } catch {
//            // handle error
//        }
//    }
//
//    private func updateMeasurements(_ measurements: [RuuviMeasurement]) async {
//        self.allMeasurements = measurements
//        // Off-main thread chart creation
//        let modules = self.determineChartModulesSync(measurements)
//        let dataSets = self.createChartDataSync(measurements)
//
//        // Then publish on main actor
//        await MainActor.run {
//            self.chartModules = modules
//            self.chartDataSets = dataSets
//            self.latestMeasurement = measurements.last
//        }
//    }
//
//    /// Check which measurement fields exist in the *latest* measurement (like old logic).
//    private func determineChartModules() async {
//        guard let sensor = sensor else { return }
//        // read the latest record again or check `latestMeasurement`
//        let record = try? await ruuviStorage.readLatest(sensor).asyncValue()
//        let measurement = record?.measurement
//
//        let modules = self.determineChartModulesSync(measurement.map { [$0] } ?? [])
//        await MainActor.run {
//            self.chartModules = modules
//        }
//    }
//
//    private func determineChartModulesSync(_ measurements: [RuuviMeasurement]) -> [MeasurementType] {
//        guard let last = measurements.last else { return [] }
//        var result = MeasurementType.chartsCases
//
//        if last.temperature == nil { result.removeAll { $0 == .temperature } }
//        if last.humidity == nil { result.removeAll { $0 == .humidity } }
//        if last.pressure == nil { result.removeAll { $0 == .pressure } }
//        // etc. for co2, pm2_5, nox, etc.
//
//        return result
//    }
//
//    /// Re-create the chart data sets (like your `createChartData()` method) off the main thread.
//    private func createChartDataSync(_ measurements: [RuuviMeasurement]) -> [TagChartViewData] {
//        // replicate your existing logic to build TagChartViewData
//        // e.g. group them by type -> create ChartDataEntry -> create data sets
//        // return the [TagChartViewData]
//        var result: [TagChartViewData] = []
//
//        // Example for temperature:
//        let temperatureEntries = measurements.compactMap {
//            chartEntry(for: $0, type: .temperature)
//        }
//        if !temperatureEntries.isEmpty {
//            // see your createChartData logic...
//            let ds = TagChartsHelper.newDataSet(
//                upperAlertValue: nil,
//                entries: temperatureEntries,
//                lowerAlertValue: nil,
//                showAlertRangeInGraph: false
//            )
//            let chartData = TagChartViewData(
//                upperAlertValue: nil,
//                chartType: .temperature,
//                chartData: LineChartData(dataSet: ds),
//                lowerAlertValue: nil
//            )
//            result.append(chartData)
//        }
//
//        // ... replicate for each measurement type
//
//        return result
//    }
//
//    private func chartEntry(for data: RuuviMeasurement, type: MeasurementType) -> ChartDataEntry? {
//        // replicate your old logic. e.g.:
//        switch type {
//        case .temperature:
//            if let temp = data.temperature {
//                let celsiusDouble = measurementService.double(for: temp)
//                return ChartDataEntry(
//                    x: data.date.timeIntervalSince1970,
//                    y: celsiusDouble ?? 0
//                )
//            }
//        // etc. for humidity, pressure, etc.
//        default:
//            break
//        }
//        return nil
//    }
//}
