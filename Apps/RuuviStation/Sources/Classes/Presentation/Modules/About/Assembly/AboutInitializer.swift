import UIKit

class AboutInitializer: NSObject {
    @IBOutlet var viewController: AboutViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        AboutConfigurator().configure(view: viewController)
    }
}
