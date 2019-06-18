import UIKit

class MainInitializer: NSObject {
    @IBOutlet weak var navigationController: UINavigationController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        MainConfigurator().configure(navigationController: navigationController)
    }
}
