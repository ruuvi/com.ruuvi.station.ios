import UIKit

class RuuviTagInitializer: NSObject {
    @IBOutlet weak var viewController: RuuviTagViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        RuuviTagConfigurator().configure(view: viewController)
    }
}
