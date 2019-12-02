import UIKit

class WebTagSettingsTableInitializer: NSObject {
    @IBOutlet weak var viewController: WebTagSettingsTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        WebTagSettingsTableConfigurator().configure(view: viewController)
    }
}
