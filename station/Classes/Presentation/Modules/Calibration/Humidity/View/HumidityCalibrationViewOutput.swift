import Foundation

protocol HumidityCalibrationViewOutput {
    func viewDidLoad()
    func viewDidTapOnDimmingView()
    func viewDidTriggerCancel()
    func viewDidTriggerCalibrate()
}
