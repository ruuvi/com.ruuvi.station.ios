import UIKit

class WelcomeInitializer: NSObject {
    @IBOutlet weak var viewController: WelcomeViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        WelcomeConfigurator().configure(view: viewController)
    }
}
