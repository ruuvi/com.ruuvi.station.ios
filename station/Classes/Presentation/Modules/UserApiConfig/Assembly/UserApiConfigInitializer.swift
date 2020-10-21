import UIKit

class UserApiConfigInitializer: NSObject {
    @IBOutlet weak var viewController: UserApiConfigViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        UserApiConfigConfigurator().configure(view: viewController)
    }
}
