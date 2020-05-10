import UIKit

class NetworkSettingsTableInitializer: NSObject {
    @IBOutlet weak var viewController: NetworkSettingsTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        NetworkSettingsTableConfigurator().configure(view: viewController)
    }
}
