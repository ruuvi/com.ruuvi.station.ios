import Foundation
import Future
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

    public func ruuviTagPruningOperations() -> Future<[Operation], RuuviDaemonError> {
        let promise = Promise<[Operation], RuuviDaemonError>()
        // Keep archived history in the database. Visibility limits belong to readers.
        promise.succeed(value: [])
        return promise.future
    }
}
