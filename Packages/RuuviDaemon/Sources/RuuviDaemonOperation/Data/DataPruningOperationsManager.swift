import Foundation
import Future
import RuuviDaemon
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
        ruuviStorage.readAll().on(success: { [weak self] ruuviTags in
            guard let sSelf = self else { return }
            let ops = ruuviTags.map {
                RuuviTagDataPruningOperation(
                    id: $0.id,
                    ruuviPool: sSelf.ruuviPool,
                    settings: sSelf.settings
                )
            }
            promise.succeed(value: ops)
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })
        return promise.future
    }
}
