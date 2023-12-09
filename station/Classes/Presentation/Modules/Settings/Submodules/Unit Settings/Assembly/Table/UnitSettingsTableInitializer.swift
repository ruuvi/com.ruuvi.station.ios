import UIKit

class UnitSettingsTableInitializer: NSObject {
    @IBOutlet var viewController: UnitSettingsTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        UnitSettingsTableConfigurator().configure(view: viewController)
    }
}
