import UIKit

class LanguageTableInitializer: NSObject {
    @IBOutlet weak var viewController: LanguageTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        LanguageTableConfigurator().configure(view: viewController)
    }
}
