import Foundation
import Future
import RuuviService
import RuuviVirtual
import RuuviNotifier

public final class WebTagOperationsManager {
    private let virtualProviderService: VirtualProviderService
    private let alertService: RuuviServiceAlert
    private let ruuviNotifier: RuuviNotifier
    private let virtualStorage: VirtualStorage
    private let virtualPersistence: VirtualPersistence

    public init(
        virtualProviderService: VirtualProviderService,
        alertService: RuuviServiceAlert,
        alertHandler: RuuviNotifier,
        virtualStorage: VirtualStorage,
        virtualPersistence: VirtualPersistence
    ) {
        self.virtualProviderService = virtualProviderService
        self.alertService = alertService
        self.ruuviNotifier = alertHandler
        self.virtualStorage = virtualStorage
        self.virtualPersistence = virtualPersistence
    }

    public func alertsPullOperations() -> Future<[Operation], RuuviDaemonError> {
        let promise = Promise<[Operation], RuuviDaemonError>()
        virtualStorage.readAll().on(success: { [weak self] virtualTags in
            guard let sSelf = self else { return }
            var operations = [Operation]()
            virtualTags.forEach { virtualTag in
                if sSelf.alertService.hasRegistrations(for: virtualTag) {
                    if let location = virtualTag.loc {
                        let operation = WebTagRefreshDataOperation(
                            sensor: virtualTag,
                            location: location,
                            provider: virtualTag.provider,
                            weatherProviderService: sSelf.virtualProviderService,
                            alertService: sSelf.ruuviNotifier,
                            webTagPersistence: sSelf.virtualPersistence
                        )
                        operations.append(operation)
                    } else {
                        let operation = CurrentWebTagRefreshDataOperation(
                            sensor: virtualTag,
                            provider: virtualTag.provider,
                            weatherProviderService: sSelf.virtualProviderService,
                            alertService: sSelf.ruuviNotifier,
                            webTagPersistence: sSelf.virtualPersistence
                        )
                        operations.append(operation)
                    }
                }
            }
            promise.succeed(value: operations)
        }, failure: { error in
            promise.fail(error: .virtualStorage(error))
        })
        return promise.future
    }
}
