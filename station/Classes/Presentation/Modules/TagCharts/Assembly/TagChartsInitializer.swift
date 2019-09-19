import UIKit

class TagChartsInitializer: NSObject {
    @IBOutlet weak var viewController: TagChartsViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        TagChartsConfigurator().configure(view: viewController)
    }
}
