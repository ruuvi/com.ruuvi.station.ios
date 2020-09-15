import UIKit

class SelectionTableInitializer: NSObject {
    @IBOutlet weak var viewController: SelectionTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        SelectionTableConfigurator().configure(view: viewController)
    }
}
