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
    private let migrationQueue: DispatchQueue = DispatchQueue(label: "MigrationManagerToSQLite")
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
            let threadSafeReference = ThreadSafeReference(to: realmTag)
            migrationQueue.async { [weak self, ruuviTagTank] in
                autoreleasepool {
                    let bgRealm = try! Realm()
                    guard let bgRuuviTag = bgRealm.resolve(threadSafeReference) else {
                        assertionFailure("not resolved thread safe reference")
                        return
                    }
                    var records: [RuuviTagSensorRecord] = []
                    for record in bgRuuviTag.data {
                        autoreleasepool {
                            if let anyRecord = record.any?.with(macId: mac.mac) {
                                records.append(anyRecord)
                            }
                        }
                    }
                    ruuviTagTank?.create(records)
                        .on(failure: { error in
                            self?.errorPresenter.present(error: error)
                        })

                    do {
                        try bgRealm.write {
                            bgRealm.delete(bgRuuviTag.data)
                            bgRealm.delete(bgRuuviTag)
                        }
                    } catch {
                        self?.errorPresenter.present(error: error)
                    }
                    bgRealm.invalidate()
                    bgRealm.refresh()
                }
            }
        }
    }
}
