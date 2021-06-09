import Foundation

class DfuFlashAppleInitializer: NSObject {
    @IBOutlet weak var viewController: DfuFlashAppleViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        DfuFlashConfigurator().configure(view: viewController)
    }
}
