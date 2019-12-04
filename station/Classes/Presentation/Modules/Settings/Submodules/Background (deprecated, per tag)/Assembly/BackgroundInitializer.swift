import Foundation

class BackgroundInitializer: NSObject {
    @IBOutlet weak var viewController: BackgroundViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        BackgroundConfigurator().configure(view: viewController)
    }
}
