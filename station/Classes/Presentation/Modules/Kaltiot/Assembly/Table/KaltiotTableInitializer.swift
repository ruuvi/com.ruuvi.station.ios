import UIKit

class KaltiotTableInitializer: NSObject {
    @IBOutlet weak var viewController: KaltiotPickerTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        KaltiotPickerTableConfigurator().configure(view: viewController)
    }
}
