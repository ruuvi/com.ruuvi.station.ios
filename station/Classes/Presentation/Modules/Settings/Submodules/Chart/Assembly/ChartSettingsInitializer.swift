import UIKit

class ChartSettingsInitializer: NSObject {
    @IBOutlet weak var viewController: ChartSettingsTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        ChartSettingsConfigurator().configure(view: viewController)
    }
}
