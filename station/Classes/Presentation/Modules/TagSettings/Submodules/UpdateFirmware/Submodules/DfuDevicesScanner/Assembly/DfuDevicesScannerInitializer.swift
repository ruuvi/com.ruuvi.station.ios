import Foundation

class DfuDevicesScannerInitializer: NSObject {
    @IBOutlet weak var viewController: DfuDevicesScannerTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        DfuDevicesScannerConfigurator().configure(view: viewController)
    }
}
