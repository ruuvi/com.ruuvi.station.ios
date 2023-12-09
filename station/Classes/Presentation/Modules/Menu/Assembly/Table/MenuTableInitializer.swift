import UIKit

class MenuTableInitializer: NSObject {
    @IBOutlet var viewController: MenuTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        MenuTableConfigurator().configure(view: viewController)
    }
}
