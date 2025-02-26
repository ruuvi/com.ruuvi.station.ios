//import SwiftUI
//import Combine
//import CoreBluetooth
//import DGCharts
//import RuuviOntology
//import RuuviReactor
//import RuuviService
//import RuuviStorage
//
//@MainActor
//class NewTagChartsViewModel: ObservableObject {
//    // MARK: - Published UI State
//
//    @Published var chartModules: [MeasurementType] = []
//    @Published var chartDataSets: [TagChartViewData] = []
//    @Published var latestMeasurement: RuuviMeasurement?
//    @Published var isSyncing = false
//    @Published var syncProgress: BTServiceProgress?
//    @Published var alertState: AlertState = .empty
//    @Published var isConnected: Bool = false
//    @Published var isConnectable: Bool = false
//    @Published var backgroundImage: UIImage?
//
//    // Additional state that the SwiftUI view might need:
//    @Published var errorMessage: String?
//    @Published var showBluetoothDisabledAlert = false
//
//    // MARK: - Dependencies
//
//    private let interactor: NewTagChartsInteractor
//    private let alertService: RuuviServiceAlert
//    private let measurementService: RuuviServiceMeasurement
//    private let bluetoothForeground: BTForeground
//    private let isBluetoothPermissionGranted: () -> Bool
//    private var cancellables = Set<AnyCancellable>()
//
//    // The sensor we’re displaying charts for:
//    private(set) var ruuviTag: AnyRuuviTagSensor!
//
//    // MARK: - Init
//
//    init(
//        interactor: TagChartsInteractor,
//        alertService: RuuviServiceAlert,
//        measurementService: RuuviServiceMeasurement,
//        bluetoothForeground: BTForeground,
//        isBluetoothPermissionGranted: @escaping () -> Bool
//    ) {
//        self.interactor = interactor
//        self.alertService = alertService
//        self.measurementService = measurementService
//        self.bluetoothForeground = bluetoothForeground
//        self.isBluetoothPermissionGranted = isBluetoothPermissionGranted
//
//        // Observe Bluetooth state in a Combine-friendly way, or via NotificationCenter bridging
//        bluetoothForeground.statePublisher
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] state in
//                guard let self = self else { return }
//                let permission = isBluetoothPermissionGranted()
//                // If not poweredOn or no permission => show alert
//                if state != .poweredOn || !permission {
//                    self.showBluetoothDisabledAlert = true
//                }
//            }
//            .store(in: &cancellables)
//    }
//
//    // MARK: - Public Interface
//
//    func configureSensor(_ sensor: AnyRuuviTagSensor) {
//        self.ruuviTag = sensor
//        interactor.configureSensor(sensor)
//
//        // Observe the sensor’s background in the interactor
//        interactor.$backgroundImage
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$backgroundImage)
//
//        // Observe “isConnected” events
//        interactor.$isConnected
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$isConnected)
//
//        interactor.$isConnectable
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$isConnectable)
//
//        // Observe measurement updates
//        interactor.$latestMeasurement
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] measurement in
//                self?.latestMeasurement = measurement
//            }
//            .store(in: &cancellables)
//
//        // Observe chart data changes
//        interactor.$chartDataSets
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] newDataSets in
//                self?.chartDataSets = newDataSets
//            }
//            .store(in: &cancellables)
//
//        // Observe modules (which measurements are relevant)
//        interactor.$chartModules
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$chartModules)
//
//        // Observe alert state
//        interactor.$alertState
//            .receive(on: DispatchQueue.main)
//            .assign(to: &$alertState)
//    }
//
//    func onAppear() {
//        // Start the periodic fetching / any needed tasks
//        interactor.startObservers()
//    }
//
//    func onDisappear() {
//        // Stop if needed
//        interactor.stopObservers()
//    }
//
//    func startSync() {
//        guard bluetoothForeground.bluetoothState == .poweredOn,
//              isBluetoothPermissionGranted()
//        else {
//            showBluetoothDisabledAlert = true
//            return
//        }
//
//        isSyncing = true
//        syncProgress = nil
//        Task {
//            do {
//                // The interactor’s syncRecords can be an async method
//                try await interactor.syncRecords { progress in
//                    // Update on main actor
//                    Task { @MainActor [weak self] in
//                        self?.syncProgress = progress
//                    }
//                }
//            } catch {
//                // handle error
//                await MainActor.run {
//                    self.errorMessage = "Failed to sync: \(error.localizedDescription)"
//                }
//            }
//            await MainActor.run {
//                self.isSyncing = false
//                self.syncProgress = nil
//            }
//        }
//    }
//
//    func stopSync() {
//        Task {
//            do {
//                let stopped = try await interactor.stopSyncRecords()
//                if stopped {
//                    await MainActor.run {
//                        self.isSyncing = false
//                        self.syncProgress = nil
//                    }
//                }
//            } catch {
//                await MainActor.run {
//                    self.errorMessage = "Failed to stop sync: \(error.localizedDescription)"
//                }
//            }
//        }
//    }
//}
