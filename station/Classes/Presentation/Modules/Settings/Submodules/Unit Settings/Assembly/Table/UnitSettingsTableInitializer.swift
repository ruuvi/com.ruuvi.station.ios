import UIKit

class UnitSettingsTableInitializer: NSObject {
    @IBOutlet weak var viewController: UnitSettingsTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        UnitSettingsTableConfigurator().configure(view: viewController)
    }
}
