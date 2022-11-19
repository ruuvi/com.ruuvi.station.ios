import Foundation

protocol DiscoverViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidChoose(device: DiscoverRuuviTagViewModel, displayName: String)
    func viewDidTriggerClose()
    func viewDidTriggerDisabledBTRow()
    func viewDidTriggerBuySensors()
}
