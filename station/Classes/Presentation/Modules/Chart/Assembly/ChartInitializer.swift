import UIKit

class ChartInitializer: NSObject {
    @IBOutlet weak var viewController: ChartViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        ChartConfigurator().configure(view: viewController)
    }
}
