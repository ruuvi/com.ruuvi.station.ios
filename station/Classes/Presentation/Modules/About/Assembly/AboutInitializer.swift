import UIKit

class AboutInitializer: NSObject {
    @IBOutlet weak var viewController: AboutViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        AboutConfigurator().configure(view: viewController)
    }
}
