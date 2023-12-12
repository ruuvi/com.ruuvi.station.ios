import UIKit

class SelectionTableInitializer: NSObject {
    @IBOutlet var viewController: SelectionTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        SelectionTableConfigurator().configure(view: viewController)
    }
}
