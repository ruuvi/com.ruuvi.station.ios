import UIKit

class ShareInitializer: NSObject {
    @IBOutlet weak var viewController: ShareViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        ShareConfigurator().configure(view: viewController)
    }
}
