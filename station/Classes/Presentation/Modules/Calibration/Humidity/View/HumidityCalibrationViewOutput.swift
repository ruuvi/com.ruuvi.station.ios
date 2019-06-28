import Foundation

protocol HumidityCalibrationViewOutput {
    func viewDidLoad()
    func viewDidTapOnDimmingView()
    func viewDidTriggerClose()
    func viewDidTriggerCalibrate()
    func viewDidTriggerClearCalibration()
    func viewDidConfirmToClearHumidityOffset()
}
