import UIKit

class SignInInitializer: NSObject {
    @IBOutlet weak var viewController: SignInViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        SignInConfigurator().configure(view: viewController)
    }
}
