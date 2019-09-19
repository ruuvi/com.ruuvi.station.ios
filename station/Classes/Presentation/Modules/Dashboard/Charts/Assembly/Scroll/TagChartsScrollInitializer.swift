import UIKit

class TagChartsScrollInitializer: NSObject {
    @IBOutlet weak var viewController: TagChartsScrollViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        TagChartsScrollConfigurator().configure(view: viewController)
    }
}
