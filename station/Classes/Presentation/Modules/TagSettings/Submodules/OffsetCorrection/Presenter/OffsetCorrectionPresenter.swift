import Foundation
import BTKit
import RuuviOntology
import RuuviService
import RuuviLocal
import RuuviStorage
import RuuviPresenters
import RuuviReactor

final class OffsetCorrectionPresenter: OffsetCorrectionModuleInput {
    weak var view: OffsetCorrectionViewInput!
    var router: OffsetCorrectionRouter!
    var background: BTBackground!
    var foreground: BTForeground!
    var errorPresenter: ErrorPresenter!
    var ruuviOffsetCalibrationService: RuuviServiceOffsetCalibration!
    var ruuviStorage: RuuviStorage!
    var ruuviReactor: RuuviReactor!
    var settings: RuuviLocalSettings!

    private var ruuviTagObserveToken: ObservationToken?
    private var ruuviTagObserveLastRecordToken: RuuviReactorToken?

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
            temperatureOffsetDate: nil,
            humidityOffset: nil,
            humidityOffsetDate: nil,
            pressureOffset: nil,
            pressureOffsetDate: nil
        )
        self.view.viewModel = {
            let vm = OffsetCorrectionViewModel(
                type: type, sensorSettings: self.sensorSettings
            )
            ruuviStorage.readLatest(ruuviTag).on {[weak self] record in
                if let record = record {
                    self?.lastSensorRecord = record
                    vm.update(
                        ruuviTagRecord: record
                            .with(sensorSettings: sensorSettings)
                    )
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
            case .inchesOfMercury:
                offset = correctValue.hPaFrominHg - view.viewModel.originalValue.value.bound
            case .millimetersOfMercury:
                offset = correctValue.hPaFrommmHg - view.viewModel.originalValue.value.bound
            default:
                offset = correctValue - view.viewModel.originalValue.value.bound
            }
        }
        ruuviOffsetCalibrationService.set(
            offset: offset,
            of: view.viewModel.type,
            for: ruuviTag,
            lastOriginalRecord: lastSensorRecord)
            .on(success: { [weak self] settings in
                self?.sensorSettings = settings
                self?.view.viewModel.update(sensorSettings: settings)
                if let lastRecord = self?.lastSensorRecord {
                    self?.view.viewModel.update(
                        ruuviTagRecord: lastRecord.with(sensorSettings: settings)
                    )
                }
                self?.notifyCalibrationSettingsUpdate()
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
    }

    func viewDidClearOffsetValue() {
        ruuviOffsetCalibrationService.set(
            offset: nil,
            of: view.viewModel.type,
            for: ruuviTag,
            lastOriginalRecord: lastSensorRecord)
            .on(success: { [weak self] sensorSettings in
                self?.sensorSettings = sensorSettings
                self?.view.viewModel.update(sensorSettings: sensorSettings)
                if let lastRecord = self?.lastSensorRecord {
                    self?.view.viewModel.update(
                        ruuviTagRecord: lastRecord
                            .with(sensorSettings: sensorSettings)
                    )
                }
                self?.notifyCalibrationSettingsUpdate()
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
    }

    private func notifyCalibrationSettingsUpdate() {
        NotificationCenter.default.post(name: .SensorCalibrationDidChange,
                                         object: self,
                                         userInfo: nil)
    }

    private func observeRuuviTagUpdate() {
        guard let luid = self.ruuviTag.luid?.value else {
            return
        }
        if !(settings.cloudModeEnabled && ruuviTag.isCloud) {
            ruuviTagObserveToken?.invalidate()
            ruuviTagObserveToken = foreground.observe(self, uuid: luid) { [weak self] (_, device) in
                if let ruuviTag = device.ruuvi?.tag {
                    self?.lastSensorRecord = ruuviTag
                    self?.view.viewModel.update(
                        ruuviTagRecord: ruuviTag.with(sensorSettings: self?.sensorSettings).with(source: .advertisement)
                    )
                }
            }
        } else {
            ruuviTagObserveLastRecordToken?.invalidate()
            ruuviTagObserveLastRecordToken = ruuviReactor.observeLatest(ruuviTag) { [weak self] (changes) in
                if case .update(let anyRecord) = changes,
                   let record = anyRecord {
                    self?.lastSensorRecord = record
                    self?.view.viewModel.update(
                        ruuviTagRecord: record.with(sensorSettings: self?.sensorSettings)
                    )
                }
            }
        }
    }

    private func startObservingSettingsChanges() {
        temperatureUnitSettingToken = NotificationCenter.default
            .addObserver(forName: .TemperatureUnitDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
                self?.view.viewModel.temperatureUnit.value = self?.settings.temperatureUnit
            }
        humidityUnitSettingToken = NotificationCenter.default
            .addObserver(forName: .HumidityUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                            self?.view.viewModel.humidityUnit.value = self?.settings.humidityUnit
                         })
        pressureUnitSettingToken = NotificationCenter.default
            .addObserver(forName: .PressureUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                            self?.view.viewModel.pressureUnit.value = self?.settings.pressureUnit
                         })
    }
}
