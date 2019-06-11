import UIKit

class DiscoverPulsatorInitializer: NSObject {
    @IBOutlet weak var viewController: DiscoverPulsatorViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        DiscoverPulsatorConfigurator().configure(view: viewController)
    }
}
