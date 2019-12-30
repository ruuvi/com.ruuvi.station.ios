import UIKit

class LocationPickerAppleInitializer: NSObject {
    @IBOutlet weak var viewController: LocationPickerAppleViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        LocationPickerAppleConfigurator().configure(view: viewController)
    }
}
