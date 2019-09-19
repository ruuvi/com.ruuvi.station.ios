import UIKit

class DashboardScrollInitializer: NSObject {
    @IBOutlet weak var viewController: DashboardScrollViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        DashboardScrollConfigurator().configure(view: viewController)
    }
}
