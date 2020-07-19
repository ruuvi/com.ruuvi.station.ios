import Foundation

protocol KaltiotPickerViewOutput {
    func viewDidLoad()
    func viewDidTriggerClose()
    func viewDidTriggerLoadNextPage()
    func viewDidSelectBeacon(_ beacon: KaltiotBeaconViewModel)
    func viewDidStartSearch(mac: String)
    func viewDidCancelSearch()
}
