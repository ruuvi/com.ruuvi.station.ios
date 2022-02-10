import UIKit

final class OwnerInitializer: NSObject {
    @IBOutlet weak var viewController: OwnerViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        OwnerConfigurator().configure(view: viewController)
    }
}
