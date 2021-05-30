import Foundation
import Future
import RuuviOntology
import BTKit

final class RuuviCloudPure: RuuviCloud {
    init(api: RuuviCloudApi, apiKey: String?) {
        self.api = api
        self.apiKey = apiKey
    }

    func share(macId: MACIdentifier, with email: String) -> Future<MACIdentifier, RuuviCloudError> {
        let promise = Promise<MACIdentifier, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
        api.share(request, authorization: apiKey)
            .on(success: { response in
                promise.succeed(value: response.sensor.mac)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    func unshare(macId: MACIdentifier, with email: String?) -> Future<MACIdentifier, RuuviCloudError> {
        let promise = Promise<MACIdentifier, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
        api.unshare(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: macId)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    func claim(macId: MACIdentifier) -> Future<MACIdentifier, RuuviCloudError> {
        let promise = Promise<MACIdentifier, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiClaimRequest(name: nil, sensor: macId.value)
        api.claim(request, authorization: apiKey)
            .on(success: { response in
                promise.succeed(value: response.sensor.mac)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    func unclaim(macId: MACIdentifier) -> Future<MACIdentifier, RuuviCloudError> {
        let promise = Promise<MACIdentifier, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiClaimRequest(name: nil, sensor: macId.value)
        api.unclaim(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: macId)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    func requestCode(email: String) -> Future<String, RuuviCloudError> {
        let promise = Promise<String, RuuviCloudError>()
        let request = RuuviCloudApiRegisterRequest(email: email)
        api.register(request)
            .on(success: { response in
                promise.succeed(value: response.email)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    func validateCode(code: String) -> Future<String, RuuviCloudError> {
        let promise = Promise<String, RuuviCloudError>()
        let request = RuuviCloudApiVerifyRequest(token: code)
        api.verify(request)
            .on(success: { [weak self] response in
                self?.apiKey = response.accessToken
                promise.succeed(value: response.accessToken)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    func loadSensors() -> Future<[CloudSensor], RuuviCloudError> {
        let promise = Promise<[CloudSensor], RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        api.user(authorization: apiKey).on(success: { response in
            promise.succeed(value: response.sensors)
        }, failure: { error in
            promise.fail(error: .api(error))
        })
        return promise.future
    }

    @discardableResult
    func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) -> Future<[AnyRuuviTagSensorRecord], RuuviCloudError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiGetSensorRequest(
            sensor: macId.value,
            until: until?.timeIntervalSince1970,
            since: since.timeIntervalSince1970,
            limit: 5000,
            sort: nil
        )
        api.getSensorData(request, authorization: apiKey).on(success: { [weak self] response in
            guard let sSelf = self else { return }
            let records = sSelf.decodeSensorRecords(macId: macId, response: response)
            promise.succeed(value: records)
        }, failure: { (error) in
            promise.fail(error: .api(error))
        })
        return promise.future
    }

    private var apiKey: String?
    private let api: RuuviCloudApi

    private func decodeSensorRecords(
        macId: MACIdentifier,
        response: RuuviCloudApiGetSensorResponse
    ) -> [AnyRuuviTagSensorRecord] {
        let decoder = Ruuvi.decoder
        return response.measurements.compactMap({
            guard let device = decoder.decodeNetwork(
                    uuid: macId.value,
                    rssi: $0.rssi,
                    isConnectable: true,
                    payload: $0.data
            ),
            let tag = device.ruuvi?.tag else {
                return nil
            }
            return RuuviTagSensorRecordStruct(
                ruuviTagId: macId.value,
                date: $0.date,
                source: .ruuviNetwork,
                macId: macId,
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
            ).any
        })
    }
}
