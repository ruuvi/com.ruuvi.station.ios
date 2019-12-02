import UIKit

class CardsScrollInitializer: NSObject {
    @IBOutlet weak var viewController: CardsScrollViewController!

    override func awakeFromNib() {
        super.awakeFromNib()
        CardsScrollConfigurator().configure(view: viewController)
    }
}
