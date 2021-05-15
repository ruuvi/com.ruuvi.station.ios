import Foundation
import BTKit

class OffsetCorrectionPresenter: OffsetCorrectionModuleInput {
    weak var view: OffsetCorrectionViewInput!
    var router: OffsetCorrectionRouter!
    var backgroundPersistence: BackgroundPersistence!
    var background: BTBackground!
    var foreground: BTForeground!
    var errorPresenter: ErrorPresenter!
    var ruuviTagReactor: RuuviTagReactor!
    var ruuviTagTrunk: RuuviTagTrunk!
    var settings: Settings!

    private var ruuviTagObserveToken: ObservationToken?
    private var ruuviTagObserveLastRecordToken: RUObservationToken?

    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var pressureUnitToken: NSObjectProtocol?

    private var ruuviTag: RuuviTagSensor!

    func configure(type: OffsetCorrectionType, ruuviTag: RuuviTagSensor, sensorSettings: SensorSettings?) {
        self.ruuviTag = ruuviTag

        self.view.viewModel = {
            let vm = OffsetCorrectionViewModel(
                type: type,
                sensorSettings: sensorSettings ?? SensorSettingsStruct(tagId: ruuviTag.id,
                                                                       temperatureOffset: nil,
                                                                       temperatureOffsetDate: nil,
                                                                       humidityOffset: nil,
                                                                       humidityOffsetDate: nil,
                                                                       pressureOffset: nil,
                                                                       pressureOffsetDate: nil)
            )
            ruuviTagTrunk.readLast(ruuviTag).on { record in
                if let record = record {
                    vm.update(ruuviTagRecord: record)
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

    func viewDidSetCorrectValue(correctValue: Double) {
        var offset: Double = 0
        switch view.viewModel.type {
        case .humidity:
            offset = (correctValue / 100) - view.viewModel.originalValue.value.bound
        case .pressure:
            offset = correctValue - view.viewModel.originalValue.value.bound
        default:
            offset = correctValue - view.viewModel.originalValue.value.bound
        }
        ruuviTagTrunk.updateOffsetCorrection(type: view.viewModel.type, with: offset, of: self.ruuviTag).on (success: { [weak self] success in
            self?.view.viewModel.update(sensorSettings: success)
            self?.fireOffsetCorrectionNotificationChange()
        }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
    }

    func viewDidClearOffsetValue() {
        ruuviTagTrunk.updateOffsetCorrection(type: view.viewModel.type, with: nil, of: self.ruuviTag).on (success: { [weak self] success in
            self?.view.viewModel.update(sensorSettings: success)
            self?.fireOffsetCorrectionNotificationChange()
        }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
    }

    private func fireOffsetCorrectionNotificationChange() {
        NotificationCenter
            .default
            .post(name: .OffsetCorrectionDidChange,
            object: nil,
            userInfo: [OffsetCorrectionDidChangeKey.luid: self.ruuviTag.luid,
                OffsetCorrectionDidChangeKey.ruuviTagId: self.ruuviTag.id])
    }

    private func observeRuuviTagUpdate() {
        guard let luid = self.ruuviTag.luid?.value else {
            return
        }
        ruuviTagObserveToken?.invalidate()
        ruuviTagObserveToken = foreground.observe(self, uuid: luid) { [weak self] (_, device) in
            if let ruuviTag = device.ruuvi?.tag {
                self?.view.viewModel.update(ruuviTag: ruuviTag)
            }
        }
    }

    private func startObservingSettingsChanges() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureUnitDidChange,
            object: nil,
            queue: .main) { [weak self] _ in
            self?.view.viewModel.temperatureUnit.value = self?.settings.temperatureUnit
        }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(forName: .HumidityUnitDidChange,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                self?.view.viewModel.humidityUnit.value = self?.settings.humidityUnit
            })
        pressureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .PressureUnitDidChange,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                self?.view.viewModel.pressureUnit.value = self?.settings.pressureUnit
            })
    }
}
