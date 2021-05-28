import Foundation
import Future
import RuuviOntology
import RuuviStorage
import RuuviLocal

class NetworkServiceQueue: NetworkService {

    var ruuviNetworkFactory: RuuviNetworkFactory!
    var ruuviTagTank: RuuviTagTank!
    var ruuviStorage: RuuviStorage!
    var networkPersistence: NetworkPersistence!
    var settings: RuuviLocalSettings!
    var sensorService: SensorService!

    lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    @discardableResult
    func loadData(for ruuviTagId: String, mac: String) -> Future<Int, RUError> {
        let promise = Promise<Int, RUError>()
        let operation = ruuviStorage.readOne(ruuviTagId)
        let networkPruningOffset = -TimeInterval(settings.networkPruningIntervalHours * 60 * 60)
        let networkPuningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        operation.on(success: { [weak self] sensor in
            guard let strongSelf = self else {
                return
            }
            let lastRecord = strongSelf.ruuviStorage.readLast(sensor)
            lastRecord.on(success: { (record) in
                let since: Date = record?.date
                    ?? self?.networkPersistence.lastSyncDate
                    ?? networkPuningDate
                let loadDataOperation = strongSelf.loadDataOperation(for: sensor,
                                                                     mac: mac,
                                                                     since: since)
                loadDataOperation.on(success: { (result) in
                    promise.succeed(value: result)
                    self?.networkPersistence.lastSyncDate = Date()
                 }, failure: { (error) in
                    promise.fail(error: error)
                 })
            }, failure: { _ in
                let since: Date = self?.networkPersistence.lastSyncDate
                    ?? networkPuningDate
                let loadDataOperation = strongSelf.loadDataOperation(for: sensor,
                                                                     mac: mac,
                                                                     since: since)
                loadDataOperation.on(success: { (result) in
                    promise.succeed(value: result)
                    self?.networkPersistence.lastSyncDate = Date()
                 }, failure: { (error) in
                    promise.fail(error: error)
                 })
            })
        }, failure: { _ in
            promise.fail(error: .unexpected(.failedToFindRuuviTag))
        })
        return promise.future
    }

    func updateTagsInfo() -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        ruuviStorage.readAll().on(success: { [weak self] ruuviTagSensors in
            guard let sSelf = self else { return }
            sSelf.ruuviNetworkFactory.network().user().on(success: { [weak sSelf] userApiResponse in
                guard let ssSelf = sSelf else { return }
                // TODO: - backend response with duplicate for claimed tag as not owner and owner access
                userApiResponse.sensors.forEach({ sensor in
                    sensor.isOwner = sensor.owner == userApiResponse.email
                })
                let filteredUserApiSensors = userApiResponse.sensors.filter({ sensor in
                    return !userApiResponse.sensors.contains(where: {
                        $0.sensorId == sensor.sensorId
                            && $0.isOwner != sensor.isOwner
                            && $0.isOwner
                    })
                })

                ruuviTagSensors.forEach({ sensor in
                    if let userApiSensor = filteredUserApiSensors.first(where: {$0.sensorId == sensor.macId?.value}) {
                        ssSelf.updateTag(sensor, with: userApiSensor)
                    } else {
                        ssSelf.removeClaimedFlag(for: sensor)
                    }
                })
                filteredUserApiSensors.forEach({ sensor in
                    if !ruuviTagSensors.contains(where: {$0.macId?.value == sensor.sensorId}) {
                        ssSelf.createTag(for: sensor)
                    }
                    ssSelf.loadData(for: sensor.sensorId, mac: sensor.sensorId)
                        .on(completion: {
                            promise.succeed(value: true)
                        })
                })
            }, failure: { error in
                promise.fail(error: error)
            })
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })
        return promise.future
    }
}
// MARK: - Private
extension NetworkServiceQueue {
    private func loadDataOperation(for sensor: AnyRuuviTagSensor,
                                   mac: String,
                                   since: Date) -> Future<Int, RUError> {
        let promise = Promise<Int, RUError>()
        let network = ruuviNetworkFactory.network()
        let operation = RuuviTagLoadDataOperation(ruuviTagId: sensor.id,
                                                  mac: mac,
                                                  since: since,
                                                  network: network,
                                                  ruuviTagTank: ruuviTagTank, networkPersistance: networkPersistence)
        operation.completionBlock = { [unowned operation] in
            if let error = operation.error {
                promise.fail(error: error)
            } else {
                promise.succeed(value: operation.recordsCount)
            }
        }
        queue.addOperation(operation)
        return promise.future
    }

    private func updateTag(_ sensor: RuuviTagSensor, with networkTag: UserApiUserSensor) {
        let updatedSensor = RuuviTagSensorStruct(version: sensor.version,
                                                 luid: sensor.luid,
                                                 macId: sensor.macId,
                                                 isConnectable: sensor.isConnectable,
                                                 name: networkTag.name.isEmpty ? networkTag.sensorId : networkTag.name,
                                                 isClaimed: networkTag.isOwner,
                                                 isOwner: networkTag.isOwner,
                                                 owner: networkTag.owner)
        ruuviTagTank.update(updatedSensor)
        if let pictureUrl = URL(string: networkTag.pictureUrl) {
            sensorService.ensureNetworkBackgroundIsLoaded(for: networkTag.sensorId.mac, from: pictureUrl)
        }
    }

    private func removeClaimedFlag(for sensor: RuuviTagSensor) {
        let updatedSensor = RuuviTagSensorStruct(version: sensor.version,
                                                 luid: sensor.luid,
                                                 macId: sensor.macId,
                                                 isConnectable: sensor.isConnectable,
                                                 name: sensor.name,
                                                 isClaimed: false,
                                                 isOwner: true,
                                                 owner: sensor.owner)
        ruuviTagTank.update(updatedSensor)
    }

    private func createTag(for sensor: UserApiUserSensor) {
        let name = !sensor.name.isEmpty ? sensor.name : sensor.sensorId
        let sensorStruct = RuuviTagSensorStruct(version: 5,
                                                 luid: nil,
                                                 macId: sensor.sensorId.mac,
                                                 isConnectable: true,
                                                 name: name,
                                                 isClaimed: sensor.isOwner,
                                                 isOwner: sensor.isOwner,
                                                 owner: sensor.owner)
        ruuviTagTank.create(sensorStruct)
        if let pictureUrl = URL(string: sensor.pictureUrl) {
            sensorService.ensureNetworkBackgroundIsLoaded(for: sensor.sensorId.mac, from: pictureUrl)
        }
    }
}
