import Foundation

protocol DfuDevicesScannerViewInput: ViewInput {
    var viewModels: [DfuDeviceViewModel] { get set }
    var isBluetoothEnabled: Bool { get set }
    func showBluetoothDisabled()
}
