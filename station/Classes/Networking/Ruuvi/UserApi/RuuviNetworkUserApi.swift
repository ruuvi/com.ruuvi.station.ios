import Foundation
import Future
import BTKit
import UIKit
import RuuviOntology

/// https://docs.ruuvi.com/communication/ruuvi-network/backends/serverless/user-api
protocol RuuviNetworkUserApi {
    func register(_ requestModel: UserApiRegisterRequest) -> Future<UserApiRegisterResponse, RUError>
    func verify(_ requestModel: UserApiVerifyRequest) -> Future<UserApiVerifyResponse, RUError>
    func claim(_ requestModel: UserApiClaimRequest) -> Future<UserApiClaimResponse, RUError>
    func unclaim(_ requestModel: UserApiClaimRequest) -> Future<UserApiUnclaimResponse, RUError>
    func share(_ requestModel: UserApiShareRequest) -> Future<UserApiShareResponse, RUError>
    func unshare(_ requestModel: UserApiShareRequest) -> Future<UserApiUnshareResponse, RUError>
    func shared(_ requestModel: UserApiSharedRequest) -> Future<UserApiSharedResponse, RUError>
    func user() -> Future<UserApiUserResponse, RUError>
    func getSensorData(_ requestModel: UserApiGetSensorRequest) -> Future<UserApiGetSensorResponse, RUError>
    func update(_ requestModel: UserApiSensorUpdateRequest) -> Future<UserApiSensorUpdateResponse, RUError>
    func uploadImage(_ requestModel: UserApiSensorImageUploadRequest,
                     imageData: Data,
                     uploadProgress: ((Double) -> Void)?) -> Future<UserApiSensorImageUploadResponse, RUError>
}

protocol RuuviNetworkUserApiOutput: AnyObject {
    func uploadImageUpdateProgress(_ mac: MACIdentifier, percentage: Double)
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
                                                   limit: 5000,
                                                   sort: nil)
        getSensorData(requestModel).on(success: { (response) in
            let records = self.decodeSensorRecords(ruuviTagId, mac: mac, response: response)
            promise.succeed(value: records)
        }, failure: { (error) in
            promise.fail(error: error)
        })
        return promise.future
    }

    func unclaim(_ mac: String) -> Future<Bool, RUError> {
        let requestModel = UserApiClaimRequest(name: nil, sensor: mac)
        let promise = Promise<Bool, RUError>()
        unclaim(requestModel)
            .on(success: {_ in
                promise.succeed(value: true)
            }, failure: { error in
                promise.fail(error: error)
            })
        return promise.future
    }

    func unshare(_ mac: String, for user: String?) -> Future<Bool, RUError> {
        let requestModel = UserApiShareRequest(user: user, sensor: mac)
        let promise = Promise<Bool, RUError>()
        unshare(requestModel)
            .on(success: {_ in
                promise.succeed(value: true)
            }, failure: { error in
                promise.fail(error: error)
            })
        return promise.future
    }

    func upload(image: UIImage,
                for mac: MACIdentifier,
                with output: RuuviNetworkUserApiOutput) -> Future<URL, RUError> {
        let promise = Promise<URL, RUError>()
        if let pngData = image.jpegData(compressionQuality: 1.0) {
            let requestModel = UserApiSensorImageUploadRequest(sensor: mac.mac, mimeType: .jpg)
            uploadImage(requestModel,
                        imageData: pngData,
                        uploadProgress: {(percentage) in
                            output.uploadImageUpdateProgress(mac, percentage: percentage)
                        }).on(success: { response in
                            promise.succeed(value: response.uploadURL)
                        }, failure: { error in
                            promise.fail(error: .networking(error))
                        })
        } else {
            promise.fail(error: .core(.failedToGetPngRepresentation))
        }
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
    private func decodeSensorResponse(
        responses: [UserApiGetSensorResponse]
    ) -> [(AnyRuuviTagSensor, RuuviTagSensorRecord)] {
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
                let sensor = RuuviTagSensorStruct(
                    version: tag.version,
                    luid: nil,
                    macId: $0.sensor.mac,
                    isConnectable: true,
                    name: name,
                    isClaimed: false,
                    isOwner: false,
                    owner: nil // TODO: @rinat check if nil is correct
                )
                let record = RuuviTagSensorRecordStruct(
                    ruuviTagId: sensor.id,
                    date: log.date,
                    source: .ruuviNetwork,
                    macId: $0.sensor.mac,
                    rssi: log.rssi,
                    temperature: tag.temperature,
                    humidity: tag.humidity,
                    pressure: tag.pressure,
                    acceleration: tag.acceleration,
                    voltage: tag.voltage,
                    movementCounter: tag.movementCounter,
                    measurementSequenceNumber: tag.measurementSequenceNumber,
                    txPower: tag.txPower,
                    temperatureOffset: tag.temperatureOffset,
                    humidityOffset: tag.humidityOffset,
                    pressureOffset: tag.pressureOffset
                )
                sensors.append((sensor.any, record))
            }
        })
        return sensors
    }

    private func decodeSensorRecords(_ ruuviTagId: String,
                                     mac: String,
                                     response: UserApiGetSensorResponse) -> [RuuviTagSensorRecord] {
        let decoder = Ruuvi.decoder
        return response.measurements.compactMap({
            guard let device = decoder.decodeNetwork(uuid: mac,
                                                     rssi: $0.rssi,
                                                     isConnectable: true,
                                                     payload: $0.data),
                  let tag = device.ruuvi?.tag else {
                return nil
            }
            return RuuviTagSensorRecordStruct(
                ruuviTagId: ruuviTagId,
                date: $0.date,
                source: .ruuviNetwork,
                macId: mac.mac,
                rssi: $0.rssi,
                temperature: tag.temperature,
                humidity: tag.humidity,
                pressure: tag.pressure,
                acceleration: tag.acceleration,
                voltage: tag.voltage,
                movementCounter: tag.movementCounter,
                measurementSequenceNumber: tag.measurementSequenceNumber,
                txPower: tag.txPower,
                temperatureOffset: 0.0,
                humidityOffset: 0.0,
                pressureOffset: 0.0
            )
        })
    }
}
