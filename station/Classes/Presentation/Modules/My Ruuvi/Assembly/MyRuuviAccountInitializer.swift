import UIKit

class MyRuuviAccountInitializer: NSObject {
    @IBOutlet var viewController: MyRuuviAccountViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        MyRuuviAccountConfigurator().configure(view: viewController)
    }
}
