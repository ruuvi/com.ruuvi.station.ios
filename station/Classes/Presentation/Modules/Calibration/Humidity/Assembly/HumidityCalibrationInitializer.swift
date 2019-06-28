import UIKit

class HumidityCalibrationInitializer: NSObject {
    @IBOutlet weak var viewController: HumidityCalibrationViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        HumidityCalibrationConfigurator().configure(view: viewController)
    }
}
