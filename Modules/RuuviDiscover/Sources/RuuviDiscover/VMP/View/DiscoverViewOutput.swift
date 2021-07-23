import Foundation

protocol DiscoverViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidChoose(device: DiscoverRuuviTagViewModel, displayName: String)
    func viewDidChoose(webTag: DiscoverVirtualTagViewModel)
    func viewDidTapOnGetMoreSensors()
    func viewDidTriggerClose()
    func viewDidTapOnWebTagInfo()
}
