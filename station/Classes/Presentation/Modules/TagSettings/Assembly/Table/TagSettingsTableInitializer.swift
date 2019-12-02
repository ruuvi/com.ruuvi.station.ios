import UIKit

class TagSettingsTableInitializer: NSObject {
    @IBOutlet weak var viewController: TagSettingsTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        TagSettingsTableConfigurator().configure(view: viewController)
    }
}
