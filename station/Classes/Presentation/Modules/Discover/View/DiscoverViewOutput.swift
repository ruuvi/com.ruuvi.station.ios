import Foundation

protocol DiscoverViewOutput {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidChoose(device: DiscoverDeviceViewModel, displayName: String)
    func viewDidChoose(webTag: DiscoverWebTagViewModel)
    func viewDidTapOnGetMoreSensors()
    func viewDidTriggerClose()
    func viewDidTapOnWebTagInfo()
    func viewDidAskToAddTagWithMACAddress()
    func viewDidSelectProvider(_ provider: RuuviNetworkProvider)
    func viewDidEnterKaltiotApiKey(apiKey: String)
}
