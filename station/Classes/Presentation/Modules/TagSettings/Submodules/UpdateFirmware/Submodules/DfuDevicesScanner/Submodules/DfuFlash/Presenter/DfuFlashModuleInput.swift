import RuuviDFU

protocol DfuFlashModuleInput: AnyObject {
    func configure(dfuDevice: DFUDevice)
}
