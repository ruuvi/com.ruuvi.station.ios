import UIKit

class DefaultsInitializer: NSObject {
    @IBOutlet var viewController: DefaultsViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        DefaultsConfigurator().configure(view: viewController)
    }
}
