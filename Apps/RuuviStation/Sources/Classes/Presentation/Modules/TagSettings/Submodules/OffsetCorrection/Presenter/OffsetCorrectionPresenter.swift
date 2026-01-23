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

    private var ruuviTagObserveLastRecordToken: RuuviReactorToken?
    private var sensorSettingsObserveToken: RuuviReactorToken?

    private var temperatureUnitSettingToken: NSObjectProtocol?
    private var humidityUnitSettingToken: NSObjectProtocol?
    private var pressureUnitSettingToken: NSObjectProtocol?

    private var ruuviTag: RuuviTagSensor!
    private var sensorSettings: SensorSettings!

    private var lastSensorRecord: RuuviTagSensorRecord?

    func configure(type: OffsetCorrectionType, ruuviTag: RuuviTagSensor, sensorSettings: SensorSettings?) {
        self.ruuviTag = ruuviTag
        self.sensorSettings = sensorSettings ?? SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil
        )
        view.viewModel = {
            let vm = OffsetCorrectionViewModel(
                type: type,
                sensorSettings: self.sensorSettings
            )
            Task { [weak self, weak vm] in
                guard let self, let vm else { return }
                if let record = try? await ruuviStorage.readLatest(ruuviTag) {
                    await MainActor.run {
                        self.lastSensorRecord = record
                        vm.update(
                            ruuviTagRecord: record
                                .with(sensorSettings: sensorSettings)
                        )
                    }
                }
            }
            vm.temperatureUnit.value = self.settings.temperatureUnit
            vm.humidityUnit.value = self.settings.humidityUnit
            vm.pressureUnit.value = self.settings.pressureUnit
            return vm
        }()
    }
}

extension OffsetCorrectionPresenter: OffsetCorrectionViewOutput {
    func viewDidLoad() {
        observeRuuviTagUpdate()
        observeSensorSettings()
        startObservingSettingsChanges()
    }

    func viewDidOpenCalibrateDialog() {
        view.showCalibrateDialog()
    }

    func viewDidOpenClearDialog() {
        view.showClearConfirmationDialog()
    }

    // swiftlint:disable:next cyclomatic_complexity
    func viewDidSetCorrectValue(correctValue: Double) {
        var offset: Double = 0
        switch view.viewModel.type {
        case .temperature:
            let fromTemperature = view.viewModel.originalValue.value.bound
            switch settings.temperatureUnit {
            case .celsius:
                offset = correctValue - fromTemperature
            case .fahrenheit:
                offset = correctValue.celsiusFromFahrenheit - fromTemperature
            case .kelvin:
                offset = correctValue.celsiusFromKelvin - fromTemperature
            }
        case .humidity:
            offset = (correctValue / 100) - view.viewModel.originalValue.value.bound
        case .pressure:
            switch settings.pressureUnit {
            case .hectopascals:
                offset = correctValue - view.viewModel.originalValue.value.bound
            case .newtonsPerMetersSquared:
                offset = correctValue.hPaFromPa - view.viewModel.originalValue.value.bound
            case .inchesOfMercury:
                offset = correctValue.hPaFrominHg - view.viewModel.originalValue.value.bound
            case .millimetersOfMercury:
                offset = correctValue.hPaFrommmHg - view.viewModel.originalValue.value.bound
            default:
                offset = correctValue - view.viewModel.originalValue.value.bound
            }
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let settings = try await ruuviOffsetCalibrationService.set(
                    offset: offset,
                    of: view.viewModel.type,
                    for: ruuviTag,
                    lastOriginalRecord: lastSensorRecord
                )
                await MainActor.run {
                    sensorSettings = settings
                    view.viewModel.update(sensorSettings: settings)
                    if let lastRecord = lastSensorRecord {
                        view.viewModel.update(
                            ruuviTagRecord: lastRecord.with(sensorSettings: settings)
                        )
                    }
                    notifyCalibrationSettingsUpdate()
                }
            } catch {
                await MainActor.run {
                    errorPresenter.present(error: error)
                }
            }
        }
    }

    func viewDidClearOffsetValue() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let sensorSettings = try await ruuviOffsetCalibrationService.set(
                    offset: nil,
                    of: view.viewModel.type,
                    for: ruuviTag,
                    lastOriginalRecord: lastSensorRecord
                )
                await MainActor.run {
                    self.sensorSettings = sensorSettings
                    view.viewModel.update(sensorSettings: sensorSettings)
                    if let lastRecord = lastSensorRecord {
                        view.viewModel.update(
                            ruuviTagRecord: lastRecord
                                .with(sensorSettings: sensorSettings)
                        )
                    }
                    notifyCalibrationSettingsUpdate()
                }
            } catch {
                await MainActor.run {
                    errorPresenter.present(error: error)
                }
            }
        }
    }

    private func notifyCalibrationSettingsUpdate() {
        NotificationCenter.default.post(
            name: .SensorCalibrationDidChange,
            object: self,
            userInfo: nil
        )
    }

    private func observeRuuviTagUpdate() {
        ruuviTagObserveLastRecordToken?.invalidate()
        ruuviTagObserveLastRecordToken = ruuviReactor.observeLatest(ruuviTag) { [weak self] changes in
            if case let .update(anyRecord) = changes,
               let record = anyRecord {
                self?.lastSensorRecord = record
                self?.view.viewModel.update(
                    ruuviTagRecord: record.with(sensorSettings: self?.sensorSettings)
                )
            }
        }
    }

    private func observeSensorSettings() {
        sensorSettingsObserveToken?.invalidate()
        sensorSettingsObserveToken = ruuviReactor.observe(ruuviTag) { [weak self] change in
            guard let self = self else { return }

            switch change {
            case let .update(updatedSettings):
                // Update the local cache
                self.sensorSettings = updatedSettings
                // Update the view model
                self.view.viewModel.update(sensorSettings: updatedSettings)
                // Update the displayed values with the new settings
                if let lastRecord = self.lastSensorRecord {
                    self.view.viewModel.update(
                        ruuviTagRecord: lastRecord.with(sensorSettings: updatedSettings)
                    )
                }

            case let .initial(initialSettings):
                if let firstSettings = initialSettings.first {
                    self.sensorSettings = firstSettings
                    self.view.viewModel.update(sensorSettings: firstSettings)
                    if let lastRecord = self.lastSensorRecord {
                        self.view.viewModel.update(
                            ruuviTagRecord: lastRecord.with(sensorSettings: firstSettings)
                        )
                    }
                }

            case .insert, .delete, .error:
                // No action needed for these cases
                break
            }
        }
    }

    private func startObservingSettingsChanges() {
        temperatureUnitSettingToken = NotificationCenter.default
            .addObserver(
                forName: .TemperatureUnitDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.view.viewModel.temperatureUnit.value = self?.settings.temperatureUnit
            }
        humidityUnitSettingToken = NotificationCenter.default
            .addObserver(
                forName: .HumidityUnitDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.view.viewModel.humidityUnit.value = self?.settings.humidityUnit
                }
            )
        pressureUnitSettingToken = NotificationCenter.default
            .addObserver(
                forName: .PressureUnitDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.view.viewModel.pressureUnit.value = self?.settings.pressureUnit
                }
            )
    }
}
