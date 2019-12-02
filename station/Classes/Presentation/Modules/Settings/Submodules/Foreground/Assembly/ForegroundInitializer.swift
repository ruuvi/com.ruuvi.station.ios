import Foundation

class ForegroundInitializer: NSObject {
    @IBOutlet weak var viewController: ForegroundViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        ForegroundConfigurator().configure(view: viewController)
    }
}
