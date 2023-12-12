import UIKit

class ChartSettingsInitializer: NSObject {
    @IBOutlet var viewController: ChartSettingsTableViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        ChartSettingsConfigurator().configure(view: viewController)
    }
}
