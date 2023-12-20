import UIKit

class SettingsTableInitializer: NSObject {
    @IBOutlet var viewController: SettingsTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        SettingsTableConfigurator().configure(view: viewController)
    }
}
