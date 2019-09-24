import Foundation
import BTKit
import Future

class RuuviTagServiceImpl: RuuviTagService {
    var ruuviTagPersistence: RuuviTagPersistence!
    var calibrationService: CalibrationService!
    var backgroundPersistence: BackgroundPersistence!
    
    private var connectToken: ObservationToken?
    private var logToken: ObservationToken?
    private var dropToken: ObservationToken?
    
    deinit {
        connectToken?.invalidate()
        logToken?.invalidate()
        dropToken?.invalidate()
    }
    
    func persist(ruuviTag: RuuviTag, name: String) -> Future<RuuviTag,RUError> {
        let offsetData = calibrationService.humidityOffset(for: ruuviTag.uuid)
        return ruuviTagPersistence.persist(ruuviTag: ruuviTag, name: name, humidityOffset: offsetData.0, humidityOffsetDate: offsetData.1)
    }
    
    func delete(ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        backgroundPersistence.deleteCustomBackground(for: ruuviTag.uuid)
        return ruuviTagPersistence.delete(ruuviTag: ruuviTag)
    }
    
    func update(name: String, of ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        return ruuviTagPersistence.update(name: name, of: ruuviTag)
    }
    
    func loadHistory(uuid: String, from: Date) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        connectToken = BTKit.connection.establish(for: self, uuid: uuid) { (observer, result) in
            observer.connectToken?.invalidate()
            switch result {
            case .failure(let error):
                promise.fail(error: .btkit(error))
            case .disconnected:
                promise.fail(error: .bluetooth(.disconnected))
            default:
                observer.logToken = BTKit.service.ruuvi.uart.nus.log(for: observer, uuid: uuid, from: Date.distantPast) { (observer, result) in
                    observer.logToken?.invalidate()
                    switch result {
                    case .success(let logs):
                        let op = observer.ruuviTagPersistence.persist(logs: logs, for: uuid)
                        op.on(success: { _ in
                            observer.dropToken = BTKit.connection.drop(for: observer, uuid: uuid) { (observer, result) in
                                observer.dropToken?.invalidate()
                                switch result {
                                case .failure(let error):
                                    promise.fail(error: .btkit(error))
                                default:
                                    promise.succeed(value: true)
                                }
                            }
                        }, failure: { (error) in
                            promise.fail(error: error)
                        })
                    case .failure(let error):
                        promise.fail(error: .btkit(error))
                        observer.dropToken = BTKit.connection.drop(for: observer, uuid: uuid) { (observer, result) in
                            observer.dropToken?.invalidate()
                            switch result {
                            case .failure(let error):
                                promise.fail(error: .btkit(error))
                            default:
                                break
                            }
                        }
                    }
                    
                }
            }
        }
        return promise.future
    }
    
    func clearHistory(uuid: String) -> Future<Bool,RUError> {
        return ruuviTagPersistence.clearHistory(uuid: uuid)
    }
}
