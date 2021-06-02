import Foundation

class UpdateFirmwareAppleInitializer: NSObject {
    @IBOutlet weak var viewController: UpdateFirmwareAppleViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        UpdateFirmwareConfigurator().configure(view: viewController)
    }
}
