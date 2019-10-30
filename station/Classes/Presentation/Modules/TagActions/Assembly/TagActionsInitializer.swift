import Foundation

class TagActionsInitializer: NSObject {
    @IBOutlet weak var viewController: TagActionsViewController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        TagActionsConfigurator().configure(view: viewController)
    }
}
