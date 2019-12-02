import UIKit

class SettingsTableInitializer: NSObject {
    @IBOutlet weak var viewController: SettingsTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        SettingsTableConfigurator().configure(view: viewController)
    }
}
