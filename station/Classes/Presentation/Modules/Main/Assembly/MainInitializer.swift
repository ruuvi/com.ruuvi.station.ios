import UIKit

class MainInitializer: NSObject {
    @IBOutlet weak var navigationController: UINavigationController!

    override func awakeFromNib() {
        super.awakeFromNib()
        let r = AppAssembly.shared.assembler.resolver
        // the order is important
        r.resolve(MigrationManagerToVIPER.self)?.migrateIfNeeded()
        r.resolve(SQLiteContext.self)?.database.migrateIfNeeded()
        r.resolve(MigrationManagerToSQLite.self)?.migrateIfNeeded()
        r.resolve(MigrationManagerAlertService.self)?.migrateIfNeeded()
        r.resolve(MigrationManagerToPrune240.self)?.migrateIfNeeded()
        r.resolve(MigrationManagerSensorSettings.self)?.migrateIfNeeded()
        r.resolve(NetworkService.self)?.updateTagsInfo(for: .userApi)
        MainConfigurator().configure(navigationController: navigationController)
    }
}
