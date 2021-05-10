import UIKit

class TagsManagerInitializer: NSObject {
    @IBOutlet weak var viewController: TagsManagerViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        TagsManagerConfigurator().configure(view: viewController)
    }
}
