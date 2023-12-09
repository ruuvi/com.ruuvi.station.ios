import UIKit

class OffsetCorrectionAppleInitializer: NSObject {
    @IBOutlet var viewController: OffsetCorrectionAppleViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        OffsetCorrectionConfigurator().configure(view: viewController)
    }
}
