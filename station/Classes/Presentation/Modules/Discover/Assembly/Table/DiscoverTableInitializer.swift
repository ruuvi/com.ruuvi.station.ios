import UIKit

class DiscoverTableInitializer: NSObject {
    @IBOutlet weak var viewController: DiscoverTableViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        DiscoverTableConfigurator().configure(view: viewController)
    }
}
