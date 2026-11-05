import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPresenters
import RuuviReactor
import RuuviService
import RuuviStorage

final class OffsetCorrectionPresenter: OffsetCorrectionModuleInput {
    weak var view: OffsetCorrectionViewInput!
    var router: OffsetCorrectionRouter!
    var errorPresenter: ErrorPresenter!
    var ruuviOffsetCalibrationService: RuuviServiceOffsetCalibration!
    var ruuviStorage: RuuviStorage!
    var ruuviReactor: RuuviReactor!
    var settings: RuuviLocalSettings!

    private let notificationCenter: NotificationCenter
    private var notificationTokens = [NSObjectProtocol]()
    private var lastRecordToken: RuuviReactorToken?
    private var sensorSettingsToken: RuuviReactorToken?
    private var loadTask: Task<Void, Never>?
    private var generation = UUID()
    private var isObserving = false
    private var ruuviTag: RuuviTagSensor!
    private var sensorSettings: SensorSettings!
    private var lastSensorRecord: RuuviTagSensorRecord?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    deinit {
        loadTask?.cancel()
        lastRecordToken?.invalidate()
        sensorSettingsToken?.invalidate()
        notificationTokens.forEach(notificationCenter.removeObserver)
    }

    func configure(type: OffsetCorrectionType, ruuviTag: RuuviTagSensor, sensorSettings: SensorSettings?) {
        loadTask?.cancel()
        generation = UUID()
        self.ruuviTag = ruuviTag
        self.sensorSettings = sensorSettings ?? emptySettings()
        lastSensorRecord = nil
        let model = OffsetCorrectionViewModel(type: type, sensorSettings: self.sensorSettings)
        model.temperatureUnit.value = settings.temperatureUnit
        model.humidityUnit.value = settings.humidityUnit
        model.pressureUnit.value = settings.pressureUnit
        view.viewModel = model
        let generation = generation
        loadTask = Task { @MainActor [weak self, storage = ruuviStorage!] in
            do {
                let record = try await storage.readLatest(ruuviTag)
                guard let self, self.generation == generation, !Task.isCancelled, let record else { return }
                self.update(record: record)
            } catch {
                // A live observation may still supply a reading when the initial read fails.
            }
        }
        if isObserving { observeSensor() }
    }

    private func emptySettings() -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid, macId: ruuviTag.macId,
            temperatureOffset: nil, humidityOffset: nil, pressureOffset: nil)
    }

    private func update(record: RuuviTagSensorRecord) {
        if let previous = lastSensorRecord, record.date < previous.date { return }
        lastSensorRecord = record
        view.viewModel.update(ruuviTagRecord: record.with(sensorSettings: sensorSettings))
    }

    private func update(sensorSettings: SensorSettings) {
        self.sensorSettings = sensorSettings
        view.viewModel.update(sensorSettings: sensorSettings)
        if let lastSensorRecord { update(record: lastSensorRecord) }
    }
}

extension OffsetCorrectionPresenter: OffsetCorrectionViewOutput {
    func viewDidLoad() {
        isObserving = true
        observeSensor()
        observeUnits()
    }

    func viewDidOpenCalibrateDialog() { view.showCalibrateDialog() }
    func viewDidOpenClearDialog() { view.showClearConfirmationDialog() }

    func viewDidSetCorrectValue(correctValue: Double) {
        guard correctValue.isFinite, let original = view.viewModel.originalValue.value, original.isFinite else {
            return
        }
        let offset: Double
        switch view.viewModel.type {
        case .temperature:
            offset =
                Temperature(value: correctValue, unit: settings.temperatureUnit.unitTemperature)
                .converted(to: .celsius).value - original
        case .humidity:
            offset = correctValue / 100 - original
        case .pressure:
            offset =
                Pressure(value: correctValue, unit: settings.pressureUnit)
                .converted(to: .hectopascals).value - original
        }
        guard offset.isFinite else { return }
        save(offset: offset)
    }

    func viewDidClearOffsetValue() { save(offset: nil) }

    private func save(offset: Double?) {
        let generation = generation
        let correctionType = view.viewModel.type
        Task {
            @MainActor [
                weak self, service = ruuviOffsetCalibrationService!, sensor = ruuviTag!,
                record = lastSensorRecord
            ] in
            do {
                let settings = try await service.set(
                    offset: offset, of: correctionType, for: sensor, lastOriginalRecord: record)
                guard let self, self.generation == generation else { return }
                self.update(sensorSettings: settings)
                self.notificationCenter.post(name: .SensorCalibrationDidChange, object: self)
            } catch {
                guard let self, self.generation == generation else { return }
                self.errorPresenter.present(error: error)
            }
        }
    }
}

private extension OffsetCorrectionPresenter {
    func observeSensor() {
        lastRecordToken?.invalidate()
        sensorSettingsToken?.invalidate()
        let generation = generation
        lastRecordToken = ruuviReactor.observeLatest(ruuviTag) { [weak self] change in
            guard let self, self.generation == generation else { return }
            switch change {
            case .initial(let records):
                if let newest = records.compactMap({ $0 }).max(by: { $0.date < $1.date }) {
                    self.update(record: newest)
                }
            case .update(let record), .insert(let record):
                if let record { self.update(record: record) }
            case .delete, .error:
                break
            }
        }
        sensorSettingsToken = ruuviReactor.observe(ruuviTag) { [weak self] change in
            guard let self, self.generation == generation else { return }
            switch change {
            case .initial(let settings):
                if let first = settings.first { self.update(sensorSettings: first) }
            case .update(let settings), .insert(let settings):
                self.update(sensorSettings: settings)
            case .delete:
                self.update(sensorSettings: self.emptySettings())
            case .error:
                break
            }
        }
    }

    func observeUnits() {
        notificationTokens.forEach(notificationCenter.removeObserver)
        let changes: [(Notification.Name, (OffsetCorrectionPresenter) -> Void)] = [
            (.TemperatureUnitDidChange, { $0.view.viewModel.temperatureUnit.value = $0.settings.temperatureUnit }),
            (.HumidityUnitDidChange, { $0.view.viewModel.humidityUnit.value = $0.settings.humidityUnit }),
            (.PressureUnitDidChange, { $0.view.viewModel.pressureUnit.value = $0.settings.pressureUnit }),
        ]
        notificationTokens = changes.map { name, update in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                update(self)
            }
        }
    }
}
