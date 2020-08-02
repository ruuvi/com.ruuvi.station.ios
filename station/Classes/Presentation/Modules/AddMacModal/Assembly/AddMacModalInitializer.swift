import UIKit

class AddMacModalInitializer: NSObject {
    @IBOutlet weak var viewController: AddMacModalViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        AddMacModalConfigurator().configure(view: viewController)
    }
}
