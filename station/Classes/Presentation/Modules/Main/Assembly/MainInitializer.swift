import UIKit
import RuuviContext
import RuuviService
import RuuviMigration

class MainInitializer: NSObject {
    @IBOutlet weak var navigationController: UINavigationController!

    override func awakeFromNib() {
        super.awakeFromNib()
        let r = AppAssembly.shared.assembler.resolver
        // the order is important
        r.resolve(RuuviMigration.self, name: "realm")?
            .migrateIfNeeded()
        r.resolve(SQLiteContext.self)?
            .database
            .migrateIfNeeded()
        r.resolve(RuuviMigrationFactory.self)?
            .createAllOrdered()
            .forEach({ $0.migrateIfNeeded() })
        MainConfigurator().configure(navigationController: navigationController)
    }
}
