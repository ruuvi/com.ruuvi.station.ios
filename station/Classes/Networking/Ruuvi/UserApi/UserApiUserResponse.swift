import Foundation
import Future
import BTKit

/// https://docs.ruuvi.com/communication/ruuvi-network/backends/serverless/user-api
protocol RuuviNetworkUserApi: RuuviNetwork {
    func register(_ requestModel: UserApiRegisterRequest) -> Future<UserApiRegisterResponse, RUError>
    func verify(_ requestModel: UserApiVerifyRequest) -> Future<UserApiVerifyResponse, RUError>
    func claim(_ requestModel: UserApiClaimRequest) -> Future<UserApiClaimResponse, RUError>
    func unclaim(_ requestModel: UserApiClaimRequest) -> Future<UserApiUnclaimResponse, RUError>
    func share(_ requestModel: UserApiShareRequest) -> Future<UserApiShareResponse, RUError>
    func user() -> Future<UserApiUserResponse, RUError>
    func getSensorData(_ requestModel: UserApiGetSensorRequest) -> Future<UserApiGetSensorResponse, RUError>
    func update(_ requestModel: UserApiSensorUpdateRequest) -> Future<UserApiSensorUpdateResponse, RUError>
    func uploadImage(_ requestModel: UserApiSensorImageUploadRequest,
                     imageData: Data) -> Future<UserApiSensorImageUploadResponse, RUError>
}

extension RuuviNetworkUserApi {
    func load(ruuviTagId: String,
              mac: String,
              since: Date?,
              until: Date?) -> Future<[RuuviTagSensorRecord], RUError> {
        let promise = Promise<[RuuviTagSensorRecord], RUError>()
        let requestModel = UserApiGetSensorRequest(sensor: mac,
                                                   until: until?.timeIntervalSince1970,
                                                   since: since?.timeIntervalSince1970,
                                                   limit: nil,
                                                   sort: nil)
        getSensorData(requestModel).on(success: { (response) in
            let records = self.decodeSensorRecords(ruuviTagId, mac: mac, response: response)
            promise.succeed(value: records)
        }, failure: { (error) in
            promise.fail(error: error)
        })
        return promise.future
    }
}

extension RuuviNetworkUserApi {
    func getTags(tags: [String]) -> Future<[(AnyRuuviTagSensor, RuuviTagSensorRecord)], RUError> {
        let requestModels: [UserApiGetSensorRequest] = tags.map({
            UserApiGetSensorRequest(sensor: $0,
                                    until: nil,
                                    since: nil,
                                    limit: 1,
                                    sort: nil)
        })
        let promise = Promise<[(AnyRuuviTagSensor, RuuviTagSensorRecord)], RUError>()
        let futures = requestModels.map({
            self.getSensorData($0)
        })
        Future.zip(futures).on(success: { (responses) in
            let sensors = self.decodeSensorResponse(responses: responses)
            promise.succeed(value: sensors)
        }, failure: { (error) in
            promise.fail(error: error)
        })
        return promise.future
    }
}
// MARK: - Private
extension RuuviNetworkUserApi {
    private func decodeSensorResponse(responses: [UserApiGetSensorResponse]) -> [(AnyRuuviTagSensor, RuuviTagSensorRecord)] {
        let decoder = Ruuvi.decoder
        var sensors: [(AnyRuuviTagSensor, RuuviTagSensorRecord)] = []
        responses.forEach({
            if let log = $0.measurements.first,
               let device = decoder.decodeNetwork(uuid: $0.sensor.mac.value,
                                                  rssi: log.rssi,
                                                  isConnectable: true,
                                                  payload: log.data),
               let tag = device.ruuvi?.tag {
                let name = $0.name.isEmpty ? $0.sensor : $0.name
                let sensor = RuuviTagSensorStruct(version: tag.version,
                                              luid: nil,
                                              macId: $0.sensor.mac,
                                              isConnectable: true,
                                              name: name,
                                              networkProvider: .userApi,
                                              isClaimed: false,
                                              isOwner: false)
                let record = RuuviTagSensorRecordStruct(ruuviTagId: sensor.id,
                                                        date: log.date,
                                                        macId: $0.sensor.mac,
                                                        rssi: log.rssi,
                                                        temperature: tag.temperature,
                                                        humidity: tag.humidity,
                                                        pressure: tag.pressure,
                                                        acceleration: tag.acceleration,
                                                        voltage: tag.voltage,
                                                        movementCounter: tag.movementCounter,
                                                        measurementSequenceNumber: tag.measurementSequenceNumber,
                                                        txPower: tag.txPower)
                sensors.append((sensor.any, record))
            }
        })
        return sensors
    }

    private func decodeSensorRecords(_ ruuviTagId: String, mac: String, response: UserApiGetSensorResponse) -> [RuuviTagSensorRecord] {
        let decoder = Ruuvi.decoder
        return response.measurements.compactMap({
            guard let device = decoder.decodeNetwork(uuid: mac,
                                                     rssi: $0.rssi,
                                                     isConnectable: true,
                                                     payload: $0.data),
                  let tag = device.ruuvi?.tag else {
                return nil
            }
            return RuuviTagSensorRecordStruct(ruuviTagId: ruuviTagId,
                                              date: $0.date,
                                              macId: mac.mac,
                                              rssi: $0.rssi,
                                              temperature: tag.temperature,
                                              humidity: tag.humidity,
                                              pressure: tag.pressure,
                                              acceleration: tag.acceleration,
                                              voltage: tag.voltage,
                                              movementCounter: tag.movementCounter,
                                              measurementSequenceNumber: tag.measurementSequenceNumber,
                                              txPower: tag.txPower)
        })
    }
}
