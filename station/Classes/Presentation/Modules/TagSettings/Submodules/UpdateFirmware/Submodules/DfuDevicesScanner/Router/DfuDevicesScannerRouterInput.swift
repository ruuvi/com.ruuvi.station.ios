import RuuviDFU

protocol DfuDevicesScannerRouterInput: AnyObject {
    func dismiss()
    func openFlashFirmware(_ dfuDevice: DFUDevice)
}
