import UIKit

class HeartbeatInitializer: NSObject {
    @IBOutlet weak var viewController: HeartbeatViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        HeartbeatConfigurator().configure(view: viewController)
    }
}
