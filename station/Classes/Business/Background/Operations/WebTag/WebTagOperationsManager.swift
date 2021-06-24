import Foundation
import Future
import RuuviService
import RuuviVirtual
import RuuviNotifier

class WebTagOperationsManager {
    var weatherProviderService: VirtualProviderService!
    var alertService: RuuviServiceAlert!
    var alertHandler: RuuviNotifier!
    var virtualStorage: VirtualStorage!
    var virtualPersistence: VirtualPersistence!

    func alertsPullOperations() -> Future<[Operation], RUError> {
        let promise = Promise<[Operation], RUError>()
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
                            weatherProviderService: sSelf.weatherProviderService,
                            alertService: sSelf.alertHandler,
                            webTagPersistence: sSelf.virtualPersistence
                        )
                        operations.append(operation)
                    } else {
                        let operation = CurrentWebTagRefreshDataOperation(
                            sensor: virtualTag,
                            provider: virtualTag.provider,
                            weatherProviderService: sSelf.weatherProviderService,
                            alertService: sSelf.alertHandler,
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
