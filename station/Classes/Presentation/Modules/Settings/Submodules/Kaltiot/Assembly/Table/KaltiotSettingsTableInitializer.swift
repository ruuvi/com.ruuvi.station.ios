import UIKit

class KaltiotSettingsTableInitializer: NSObject {
    @IBOutlet weak var viewController: KaltiotSettingsTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        KaltiotSettingsTableConfigurator().configure(view: viewController)
    }
}
