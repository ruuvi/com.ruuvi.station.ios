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
//            AlertType.allCases.forEach({ type in
//                if let alert = alertPersistence.alert(for: realmTag.uuid, of: type) {
//                    alertPersistence.register(type: alert, for: mac)
//                }
//            })
//            if let image = backgroundPersistence.background(for: realmTag.uuid.luid) {
//                backgroundPersistence.setCustomBackground(image: image, for: mac)
//                    .on(failure: { [weak self] error in
//                        self?.errorPresenter.present(error: error)
//                    })
//            }
//            let humidityOffset = calibrationPersistence.humidityOffset(for: realmTag.uuid.luid)
//            calibrationPersistence.setHumidity(date: humidityOffset.1, offset: humidityOffset.0, for: mac)

//            let keepConnection = connectionPersistence.keepConnection(to: realmTag.uuid.luid)
//            connectionPersistence.setKeepConnection(keepConnection, for: mac)

            idPersistence.set(mac: mac, for: realmTag.uuid.luid)

//            if settingsPersistence.keepConnectionDialogWasShown(for: realmTag.uuid.luid) {
//                settingsPersistence.setKeepConnectionDialogWasShown(for: realmTag.uuid.luid)
//            }

            ruuviTagTank.create(realmTag)
                .on(failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
            let records: [RuuviTagSensorRecord] = realmTag.data.compactMap({ $0.any?.with(mac: mac) })
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
