import UIKit

class MainInitializer: NSObject {
    @IBOutlet weak var navigationController: UINavigationController!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let r = AppAssembly.shared.assembler.resolver
        r.resolve(MigrationManager.self)?.migrateIfNeeded()
        MainConfigurator().configure(navigationController: navigationController)
    }
}
