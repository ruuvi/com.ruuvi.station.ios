import Foundation
import BTKit

class HumidityCalibrationPresenter: HumidityCalibrationModuleInput {
    weak var view: HumidityCalibrationViewInput!
    var router: HumidityCalibrationRouterInput!
    var calibrationService: CalibrationService!
    var errorPresenter: ErrorPresenter!
    
    private let scanner = Ruuvi.scanner
    private var ruuviTag: RuuviTagRealm!
    private var lastHumidityValue: Double!
    
    func configure(ruuviTag: RuuviTagRealm, lastHumidityValue: Double) {
        self.ruuviTag = ruuviTag
        self.lastHumidityValue = lastHumidityValue
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
    
    func viewDidTriggerCancel() {
        router.dismiss()
    }
    
    func viewDidTriggerCalibrate() {
        let update = calibrationService.calibrateHumiditySaltTest(currentValue: lastHumidityValue, for: ruuviTag)
        update.on(success: { [weak self] _ in
            self?.router.dismiss()
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
}

// MARK: - Scanning
extension HumidityCalibrationPresenter {
    private func startScanningHumidity() {
        scanner.observe(self, uuid: ruuviTag.uuid) { [weak self] (observer, device) in
            if let tag = device.ruuvi?.tag {
                self?.lastHumidityValue = tag.humidity
                self?.updateView()
            }
        }
    }
}

// MARK: - Private
extension HumidityCalibrationPresenter {
    func updateView() {
        view.oldHumidity = lastHumidityValue
        view.humidityOffset = ruuviTag.humidityOffset
        view.lastCalibrationDate = ruuviTag.humidityOffsetDate
    }
}
