import Foundation

class DaemonsInitializer: NSObject {
    @IBOutlet weak var viewController: DaemonsViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        DaemonsConfigurator().configure(view: viewController)
    }
}
