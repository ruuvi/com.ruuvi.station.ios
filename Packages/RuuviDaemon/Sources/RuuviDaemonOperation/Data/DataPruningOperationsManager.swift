import Foundation
import Future
import RuuviStorage
import RuuviLocal
import RuuviPool
import RuuviVirtual
import RuuviDaemon

public final class DataPruningOperationsManager {
    private let settings: RuuviLocalSettings
    private let virtualStorage: VirtualStorage
    private let virtualRepository: VirtualRepository
    private let ruuviStorage: RuuviStorage
    private let ruuviPool: RuuviPool

    public init(
        settings: RuuviLocalSettings,
        virtualStorage: VirtualStorage,
        virtualRepository: VirtualRepository,
        ruuviStorage: RuuviStorage,
        ruuviPool: RuuviPool
    ) {
        self.settings = settings
        self.virtualStorage = virtualStorage
        self.virtualRepository = virtualRepository
        self.ruuviStorage = ruuviStorage
        self.ruuviPool = ruuviPool
    }

    public func webTagPruningOperations() -> Future<[Operation], RuuviDaemonError> {
        let promise = Promise<[Operation], RuuviDaemonError>()
        virtualStorage.readAll().on(success: { [weak self] virtualTags in
            guard let sSelf = self else { return }
            let ops = virtualTags.map({
                WebTagDataPruningOperation(id: $0.id,
                                           virtualTagTank: sSelf.virtualRepository,
                                           settings: sSelf.settings)
            })
            promise.succeed(value: ops)
        }, failure: { error in
            promise.fail(error: .virtualStorage(error))
        })
        return promise.future
    }

    public func ruuviTagPruningOperations() -> Future<[Operation], RuuviDaemonError> {
        let promise = Promise<[Operation], RuuviDaemonError>()
        ruuviStorage.readAll().on(success: { [weak self] ruuviTags in
            guard let sSelf = self else { return }
            let ops = ruuviTags.map({
                RuuviTagDataPruningOperation(
                    id: $0.id,
                    ruuviPool: sSelf.ruuviPool,
                    settings: sSelf.settings
                )
            })
            promise.succeed(value: ops)
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })
        return promise.future
    }

}
