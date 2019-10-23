import Foundation
import BTKit

class HumidityCalibrationPresenter: HumidityCalibrationModuleInput {
    weak var view: HumidityCalibrationViewInput!
    var router: HumidityCalibrationRouterInput!
    var calibrationService: CalibrationService!
    var errorPresenter: ErrorPresenter!
    var foreground: BTForeground!
    
    private var ruuviTag: RuuviTagRealm!
    private var humidity: Double!
    
    func configure(ruuviTag: RuuviTagRealm, humidity: Double) {
        self.ruuviTag = ruuviTag
        self.humidity = humidity
        updateView()
    }
}

extension HumidityCalibrationPresenter: HumidityCalibrationViewOutput {
    func viewDidLoad() {
        startScanningHumidity()
    }
    
    func viewDidTapOnDimmingView() {
        router.dismiss()
    }
    
    func viewDidTriggerClose() {
        router.dismiss()
    }
    
    func viewDidTriggerClearCalibration() {
        view.showClearCalibrationConfirmationDialog()
    }
    
    func viewDidConfirmToClearHumidityOffset() {
        let clear = calibrationService.cleanHumidityCalibration(for: ruuviTag)
        clear.on(success: { [weak self] _ in
            self?.updateView()
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
    
    func viewDidConfirmToCalibrateHumidityOffset() {
        let update = calibrationService.calibrateHumiditySaltTest(currentValue: humidity, for: ruuviTag)
        update.on(success: { [weak self] _ in
            self?.updateView()
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
    
    func viewDidTriggerCalibrate() {
        view.showCalibrationConfirmationDialog()
    }
}

// MARK: - Scanning
extension HumidityCalibrationPresenter {
    private func startScanningHumidity() {
        foreground.observe(self, uuid: ruuviTag.uuid) { [weak self] (observer, device) in
            if let tag = device.ruuvi?.tag {
                self?.humidity = tag.humidity
                self?.updateView()
            }
        }
    }
}

// MARK: - Private
extension HumidityCalibrationPresenter {
    func updateView() {
        view.oldHumidity = humidity
        view.humidityOffset = ruuviTag.humidityOffset
        view.lastCalibrationDate = ruuviTag.humidityOffsetDate
    }
}
