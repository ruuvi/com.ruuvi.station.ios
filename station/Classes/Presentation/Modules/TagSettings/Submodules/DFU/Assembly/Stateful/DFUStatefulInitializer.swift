import Foundation

class DFUStatefulInitializer: NSObject {
    @IBOutlet weak var viewController: DFUStatefulViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        DFUStatefulConfigurator().configure(view: viewController)
    }
}
