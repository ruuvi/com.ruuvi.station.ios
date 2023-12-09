import Foundation
import RealmSwift
import RuuviContext
import RuuviLocal
import RuuviMigration
import RuuviOntology
import RuuviPool
#if canImport(RuuviOntologyRealm)
    import RuuviOntologyRealm
#endif

extension Notification.Name {
    static let MigrationManagerToSQLiteDidFinish = Notification.Name("MigrationManagerToSQLite.DidFinish")
}

class MigrationManagerToSQLite: RuuviMigration {
    private let idPersistence: RuuviLocalIDs
    private let realmContext: RealmContext
    private let ruuviPool: RuuviPool

    init(
        idPersistence: RuuviLocalIDs,
        realmContext: RealmContext,
        ruuviPool: RuuviPool
    ) {
        self.idPersistence = idPersistence
        self.realmContext = realmContext
        self.ruuviPool = ruuviPool
    }

    @UserDefault("MigrationManagerToSQLite.didMigrateRuuviTagRealmWithMAC", defaultValue: false)
    private var didMigrateRuuviTagRealmWithMAC: Bool

    func migrateIfNeeded() {
        if !didMigrateRuuviTagRealmWithMAC {
            let realmTags = realmContext.main.objects(RuuviTagRealm.self)
            let dispatchGroup = DispatchGroup()
            realmTags.forEach {
                dispatchGroup.enter()
                migrate(realmTag: $0, group: dispatchGroup)
            }
            dispatchGroup.notify(queue: .main) {
                NotificationCenter
                    .default
                    .post(name: .MigrationManagerToSQLiteDidFinish,
                          object: self,
                          userInfo: nil)
            }
            didMigrateRuuviTagRealmWithMAC = true
        }
    }

    private func migrate(realmTag: RuuviTagRealm, group: DispatchGroup) {
        if let mac = realmTag.mac, !mac.isEmpty {
            idPersistence.set(mac: mac.mac, for: realmTag.uuid.luid)
            ruuviPool.create(realmTag).on()
            var records: [RuuviTagSensorRecord] = []
            for record in realmTag.data {
                autoreleasepool {
                    if let anyRecord = record.any?.with(macId: mac.mac) {
                        records.append(anyRecord)
                    }
                }
            }
            ruuviPool.create(records)
                .on(completion: {
                    group.leave()
                })
            do {
                try realmContext.main.write {
                    realmContext.main.delete(realmTag.data)
                    realmContext.main.delete(realmTag)
                }
            } catch {
                print(error.localizedDescription)
            }
        } else {
            group.leave()
        }
    }
}
