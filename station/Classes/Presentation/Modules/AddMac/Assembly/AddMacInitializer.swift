import UIKit

class AddMacInitializer: NSObject {
    @IBOutlet weak var viewController: AddMacViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        AddMacConfigurator().configure(view: viewController)
    }
}
