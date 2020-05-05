import Foundation
import RealmSwift

class MigrationManagerToSQLite: MigrationManager {

    // persistence
    var alertPersistence: AlertPersistence!
    var backgroundPersistence: BackgroundPersistence!
    var calibrationPersistence: CalibrationPersistence!
    var connectionPersistence: ConnectionPersistence!
    var idPersistence: IDPersistence!
    var settingsPersistence: Settings!

    // context
    var realmContext: RealmContext!
    var sqliteContext: SQLiteContext!

    // presenter
    var errorPresenter: ErrorPresenter!

    // car
    var ruuviTagTank: RuuviTagTank!

    @UserDefault("MigrationManagerToSQLite.didMigrateRuuviTagRealmWithMAC", defaultValue: false)
    private var didMigrateRuuviTagRealmWithMAC: Bool

    func migrateIfNeeded() {
        if !didMigrateRuuviTagRealmWithMAC {
            let realmTags = realmContext.main.objects(RuuviTagRealm.self)
            realmTags.forEach({ migrate(realmTag: $0) })
            didMigrateRuuviTagRealmWithMAC = true
        }
    }

    private func migrate(realmTag: RuuviTagRealm) {
        if let mac = realmTag.mac {
            idPersistence.set(mac: mac.mac, for: realmTag.uuid.luid)

            ruuviTagTank.create(realmTag)
                .on(failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
            let records: [RuuviTagSensorRecord] = realmTag.data.compactMap({ $0.any?.with(macId: mac.mac) })
            
            ruuviTagTank.create(records)
                .on(failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })

            do {
                try self.realmContext.main.write {
                    self.realmContext.main.delete(realmTag.data)
                    self.realmContext.main.delete(realmTag)
                }
            } catch {
                errorPresenter.present(error: error)
            }
        }
    }
}
