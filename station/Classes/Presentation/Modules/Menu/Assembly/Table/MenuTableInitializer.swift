import UIKit

class MenuTableInitializer: NSObject {
    @IBOutlet weak var viewController: MenuTableViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        MenuTableConfigurator().configure(view: viewController)
    }
}
