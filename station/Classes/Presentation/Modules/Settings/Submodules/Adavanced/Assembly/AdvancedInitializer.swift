import UIKit

class AdvancedInitializer: NSObject {
    @IBOutlet weak var viewController: AdvancedTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        AdvancedConfigurator().configure(view: viewController)
    }
}
