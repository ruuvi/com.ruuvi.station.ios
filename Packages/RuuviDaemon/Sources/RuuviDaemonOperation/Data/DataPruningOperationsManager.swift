#if SWIFT_PACKAGE
    import RuuviDaemon
    import RuuviNotifier
    import RuuviOntology
#endif
import Foundation
import RuuviLocal
import RuuviPool
import RuuviStorage

public final class DataPruningOperationsManager {
    private let settings: RuuviLocalSettings
    private let ruuviStorage: RuuviStorage
    private let ruuviPool: RuuviPool

    public init(
        settings: RuuviLocalSettings,
        ruuviStorage: RuuviStorage,
        ruuviPool: RuuviPool
    ) {
        self.settings = settings
        self.ruuviStorage = ruuviStorage
        self.ruuviPool = ruuviPool
    }

    public func ruuviTagPruningOperations() async throws(RuuviDaemonError) -> [Operation] {
        // Keep archived history in the database. Visibility limits belong to readers.
        []
    }
}
