import Foundation
import RealmSwift

class MigrationManagerToSQLite: MigrationManager {

    // persistence
    var alert: AlertPersistence!
    var background: BackgroundPersistence!
    var calibration: CalibrationPersistence!
    var connection: ConnectionPersistence!
    var id: IDPersistence!
    var image: ImagePersistence!
    var settings: Settings!

    // context
    var realm: RealmContext!
    var sqlite: SQLiteContext!

    func migrateIfNeeded() {

    }
}
