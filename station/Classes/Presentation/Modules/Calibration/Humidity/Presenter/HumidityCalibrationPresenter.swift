import Foundation

class HumidityCalibrationPresenter: HumidityCalibrationModuleInput {
    weak var view: HumidityCalibrationViewInput!
    var router: HumidityCalibrationRouterInput!
    
    private var ruuviTag: RuuviTagRealm!
    
    func configure(ruuviTag: RuuviTagRealm) {
        self.ruuviTag = ruuviTag
    }
}

extension HumidityCalibrationPresenter: HumidityCalibrationViewOutput {
    func viewDidTapOnDimmingView() {
        router.dismiss()
    }
}
