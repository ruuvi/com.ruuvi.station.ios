import Foundation
import Future
import BTKit
import RuuviOntology

/// https://docs.ruuvi.com/communication/ruuvi-network/backends/serverless/user-api
protocol RuuviCloudApi {
    func register(
        _ requestModel: RuuviCloudApiRegisterRequest
    ) -> Future<RuuviCloudApiRegisterResponse, RuuviCloudApiError>

    func verify(
        _ requestModel: RuuviCloudApiVerifyRequest
    ) -> Future<RuuviCloudApiVerifyResponse, RuuviCloudApiError>

    func claim(
        _ requestModel: RuuviCloudApiClaimRequest,
        authorization: String
    ) -> Future<RuuviCloudApiClaimResponse, RuuviCloudApiError>

    func unclaim(
        _ requestModel: RuuviCloudApiClaimRequest,
        authorization: String
    ) -> Future<RuuviCloudApiUnclaimResponse, RuuviCloudApiError>

    func share(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) -> Future<RuuviCloudApiShareResponse, RuuviCloudApiError>

    func unshare(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) -> Future<RuuviCloudApiUnshareResponse, RuuviCloudApiError>

    func shared(
        _ requestModel: RuuviCloudApiSharedRequest,
        authorization: String
    ) -> Future<RuuviCloudApiSharedResponse, RuuviCloudApiError>

    func user(
        authorization: String
    ) -> Future<RuuviCloudApiUserResponse, RuuviCloudApiError>

    func getSensorData(
        _ requestModel: RuuviCloudApiGetSensorRequest,
        authorization: String
    ) -> Future<RuuviCloudApiGetSensorResponse, RuuviCloudApiError>

    func update(
        _ requestModel: RuuviCloudApiSensorUpdateRequest,
        authorization: String
    ) -> Future<RuuviCloudApiSensorUpdateResponse, RuuviCloudApiError>

    func uploadImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        imageData: Data,
        authorization: String,
        uploadProgress: ((Double) -> Void)?
    ) -> Future<RuuviCloudApiSensorImageUploadResponse, RuuviCloudApiError>
}

protocol RuuviCloudApiOutput: AnyObject {
    func uploadImageUpdateProgress(_ mac: MACIdentifier, percentage: Double)
}

extension RuuviCloudApi {
    func load(ruuviTagId: String,
              mac: String,
              authorization: String,
              since: Date?,
              until: Date?) -> Future<[RuuviTagSensorRecord], RuuviCloudApiError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviCloudApiError>()
        let requestModel = RuuviCloudApiGetSensorRequest(
            sensor: mac,
            until: until?.timeIntervalSince1970,
            since: since?.timeIntervalSince1970,
            limit: 5000,
            sort: nil
        )
        getSensorData(requestModel, authorization: authorization).on(success: { (response) in
            let records = self.decodeSensorRecords(ruuviTagId, mac: mac, response: response)
            promise.succeed(value: records)
        }, failure: { (error) in
            promise.fail(error: error)
        })
        return promise.future
    }

    func unclaim(_ mac: String, authorization: String) -> Future<Bool, RuuviCloudApiError> {
        let requestModel = RuuviCloudApiClaimRequest(name: nil, sensor: mac)
        let promise = Promise<Bool, RuuviCloudApiError>()
        unclaim(requestModel, authorization: authorization)
            .on(success: {_ in
                promise.succeed(value: true)
            }, failure: { error in
                promise.fail(error: error)
            })
        return promise.future
    }

    func unshare(_ mac: String, for user: String?, authorization: String) -> Future<Bool, RuuviCloudApiError> {
        let requestModel = RuuviCloudApiShareRequest(user: user, sensor: mac)
        let promise = Promise<Bool, RuuviCloudApiError>()
        unshare(requestModel, authorization: authorization)
            .on(success: {_ in
                promise.succeed(value: true)
            }, failure: { error in
                promise.fail(error: error)
            })
        return promise.future
    }

    func upload(imageData: Data,
                mimeType: MimeType,
                for mac: MACIdentifier,
                authorization: String,
                with output: RuuviCloudApiOutput) -> Future<URL, RuuviCloudApiError> {
        let promise = Promise<URL, RuuviCloudApiError>()
        let requestModel = RuuviCloudApiSensorImageUploadRequest(sensor: mac.mac, mimeType: mimeType)
        uploadImage(
            requestModel,
            imageData: imageData,
            authorization: authorization,
            uploadProgress: {(percentage) in
                output.uploadImageUpdateProgress(mac, percentage: percentage)
            }).on(success: { response in
                promise.succeed(value: response.uploadURL)
            }, failure: { error in
                promise.fail(error: .networking(error))
            })
        return promise.future
    }
}

extension RuuviCloudApi {
    func getTags(
        tags: [String],
        authorization: String
    ) -> Future<[(AnyRuuviTagSensor, RuuviTagSensorRecord)], RuuviCloudApiError> {
        let requestModels: [RuuviCloudApiGetSensorRequest] = tags.map({
            RuuviCloudApiGetSensorRequest(sensor: $0,
                                    until: nil,
                                    since: nil,
                                    limit: 1,
                                    sort: nil)
        })
        let promise = Promise<[(AnyRuuviTagSensor, RuuviTagSensorRecord)], RuuviCloudApiError>()
        let futures = requestModels.map({
            self.getSensorData($0, authorization: authorization)
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
extension RuuviCloudApi {
    private func decodeSensorResponse(
        responses: [RuuviCloudApiGetSensorResponse]
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
                    networkProvider: .userApi,
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
                                     response: RuuviCloudApiGetSensorResponse) -> [RuuviTagSensorRecord] {
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
