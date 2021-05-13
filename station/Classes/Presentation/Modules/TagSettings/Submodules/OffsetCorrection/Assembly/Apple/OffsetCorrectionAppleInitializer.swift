import UIKit

class OffsetCorrectionAppleInitializer: NSObject {
    @IBOutlet weak var viewController: OffsetCorrectionAppleViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        OffsetCorrectionConfigurator().configure(view: viewController)
    }
}
