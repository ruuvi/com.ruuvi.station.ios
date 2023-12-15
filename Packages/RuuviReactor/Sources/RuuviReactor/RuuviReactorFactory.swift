import Foundation
import RuuviContext
import RuuviPersistence

public protocol RuuviReactorFactory {
    func create(
        sqliteContext: SQLiteContext,
        sqlitePersistence: RuuviPersistence
    ) -> RuuviReactor
}
