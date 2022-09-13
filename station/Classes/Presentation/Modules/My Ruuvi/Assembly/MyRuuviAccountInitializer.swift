import UIKit

class MyRuuviAccountInitializer: NSObject {
    @IBOutlet weak var viewController: MyRuuviAccountViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        MyRuuviAccountConfigurator().configure(view: viewController)
    }
}
