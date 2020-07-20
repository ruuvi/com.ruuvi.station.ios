import Foundation
import RealmSwift

extension Notification.Name {
    static let DidMigrationComplete = Notification.Name("MigrationManagerToSQLite.DidMigrationComplete")
}

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
            let dispatchGroup = DispatchGroup()
            realmTags.forEach({
                dispatchGroup.enter()
                migrate(realmTag: $0, group: dispatchGroup)
            })
            dispatchGroup.notify(queue: .main) {
                NotificationCenter
                    .default
                    .post(name: .DidMigrationComplete,
                          object: self,
                          userInfo: nil)
            }
            didMigrateRuuviTagRealmWithMAC = true
        }
    }

    private func migrate(realmTag: RuuviTagRealm, group: DispatchGroup) {
        if let mac = realmTag.mac, !mac.isEmpty {
            idPersistence.set(mac: mac.mac, for: realmTag.uuid.luid)
            ruuviTagTank.create(realmTag)
                .on(failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
            var records: [RuuviTagSensorRecord] = []
            for record in realmTag.data {
                autoreleasepool {
                    if let anyRecord = record.any?.with(macId: mac.mac) {
                        records.append(anyRecord)
                    }
                }
            }
            ruuviTagTank?.create(records)
                .on(failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                }, completion: {
                    group.leave()
                })
            do {
                try realmContext.main.write {
                    realmContext.main.delete(realmTag.data)
                    realmContext.main.delete(realmTag)
                }
            } catch {
                errorPresenter.present(error: error)
            }
        } else {
            group.leave()
        }
    }
}
