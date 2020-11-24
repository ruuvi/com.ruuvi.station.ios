import Foundation
import Future

class NetworkServiceQueue: NetworkService {

    var ruuviNetworkFactory: RuuviNetworkFactory!
    var ruuviTagTank: RuuviTagTank!
    var ruuviTagTrunk: RuuviTagTrunk!
    var networkPersistence: NetworkPersistence!

    lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    @discardableResult
    func loadData(for ruuviTagId: String, mac: String, from provider: RuuviNetworkProvider) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        let operation = ruuviTagTrunk.readOne(ruuviTagId)
        operation.on(success: { [weak self] sensor in
            guard let strongSelf = self else {
                return
            }
            let lastRecord = strongSelf.ruuviTagTrunk.readLast(sensor)
            lastRecord.on(success: { (record) in
                let since: Date? = record?.date
                let loadDataOperation = strongSelf.loadDataOperation(for: sensor,
                                                                     mac: mac,
                                                                     since: since,
                                                                     from: provider)
                loadDataOperation.on(success: { (result) in
                    promise.succeed(value: result)
                    self?.networkPersistence.lastSyncDate = Date()
                 }, failure: { (error) in
                    promise.fail(error: error)
                 })
            }, failure: { _ in
                let loadDataOperation = strongSelf.loadDataOperation(for: sensor,
                                                                     mac: mac,
                                                                     from: provider)
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

    func updateTagsInfo(for provider: RuuviNetworkProvider) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        let fetchPersistedTagsOperation = ruuviTagTrunk.readAll()
        let fetchNetworkTagsInfoOperation = ruuviNetworkFactory.network(for: provider).user()
        Future.zip(fetchPersistedTagsOperation, fetchNetworkTagsInfoOperation)
            .on(success: { (ruuviTagSensors, userApiResponse) in
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
                        self.updateTag(sensor, with: userApiSensor)
                    } else {
                        self.removeClaimedFlag(for: sensor)
                    }
                })
                filteredUserApiSensors.forEach({ sensor in
                    if !ruuviTagSensors.contains(where: {$0.macId?.value == sensor.sensorId}) {
                        self.createTag(for: sensor)
                    }
                    self.loadData(for: sensor.sensorId, mac: sensor.sensorId, from: .userApi)
                        .on(completion: {
                            promise.succeed(value: true)
                        })
                })
        }, failure: { (error) in
            promise.fail(error: error)
        })
        return promise.future
    }
}
// MARK: - Private
extension NetworkServiceQueue {
    private func loadDataOperation(for sensor: AnyRuuviTagSensor,
                                   mac: String,
                                   since: Date? = nil,
                                   from provider: RuuviNetworkProvider) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        let network = ruuviNetworkFactory.network(for: provider)
        let operation = RuuviTagLoadDataOperation(ruuviTagId: sensor.id,
                                                  mac: mac,
                                                  since: since,
                                                  network: network,
                                                  ruuviTagTank: ruuviTagTank)
        operation.completionBlock = { [unowned operation] in
            if let error = operation.error {
                promise.fail(error: error)
            } else {
                promise.succeed(value: true)
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
                                                 networkProvider: .userApi,
                                                 isClaimed: networkTag.isOwner,
                                                 isOwner: networkTag.isOwner)
        ruuviTagTank.update(updatedSensor)
    }

    private func removeClaimedFlag(for sensor: RuuviTagSensor) {
        let updatedSensor = RuuviTagSensorStruct(version: sensor.version,
                                                 luid: sensor.luid,
                                                 macId: sensor.macId,
                                                 isConnectable: sensor.isConnectable,
                                                 name: sensor.name,
                                                 networkProvider: nil,
                                                 isClaimed: false,
                                                 isOwner: true)
        ruuviTagTank.update(updatedSensor)
    }

    private func createTag(for sensor: UserApiUserSensor) {
        let name = !sensor.name.isEmpty ? sensor.name : sensor.sensorId
        let sensorStruct = RuuviTagSensorStruct(version: 5,
                                                 luid: nil,
                                                 macId: sensor.sensorId.mac,
                                                 isConnectable: true,
                                                 name: name,
                                                 networkProvider: .userApi,
                                                 isClaimed: sensor.isOwner,
                                                 isOwner: sensor.isOwner)
        ruuviTagTank.create(sensorStruct)
    }
}
