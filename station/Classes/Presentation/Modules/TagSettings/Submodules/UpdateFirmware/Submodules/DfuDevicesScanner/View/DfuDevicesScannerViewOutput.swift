import Foundation

protocol DfuDevicesScannerViewOutput: AnyObject {
    func viewDidLoad()
    func viewWillAppear()
    func viewWillDisappear()
    func viewDidOpenFlashFirmware(uuid: String)
}
