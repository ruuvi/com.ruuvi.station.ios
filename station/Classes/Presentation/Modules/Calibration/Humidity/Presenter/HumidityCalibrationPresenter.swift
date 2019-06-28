import Foundation

class HumidityCalibrationPresenter: HumidityCalibrationModuleInput {
    weak var view: HumidityCalibrationViewInput!
    var router: HumidityCalibrationRouterInput!
}

extension HumidityCalibrationPresenter: HumidityCalibrationViewOutput {
    func viewDidTapOnDimmingView() {
        router.dismiss()
    }
}
