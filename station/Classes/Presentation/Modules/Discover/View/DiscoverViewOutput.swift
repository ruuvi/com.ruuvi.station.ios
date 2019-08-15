import Foundation

protocol DiscoverViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidTriggerContinue()
    func viewDidChoose(device: DiscoverDeviceViewModel)
    func viewDidTapOnGetMoreSensors()
    func viewDidTriggerClose()
}
