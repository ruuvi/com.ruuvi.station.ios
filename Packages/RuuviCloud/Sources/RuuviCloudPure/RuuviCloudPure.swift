// swiftlint:disable file_length
import Foundation
import Future
import RuuviOntology
import BTKit

// swiftlint:disable:next type_body_length
final class RuuviCloudPure: RuuviCloud {
    init(api: RuuviCloudApi, apiKey: String?) {
        self.api = api
        self.apiKey = apiKey
    }

    @discardableResult
    func set(temperatureUnit: TemperatureUnit) -> Future<TemperatureUnit, RuuviCloudError> {
        let promise = Promise<TemperatureUnit, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .unitTemperature,
            value: temperatureUnit.ruuviCloudApiSettingString
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: temperatureUnit)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    func set(humidityUnit: HumidityUnit) -> Future<HumidityUnit, RuuviCloudError> {
        let promise = Promise<HumidityUnit, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .unitHumidity,
            value: humidityUnit.ruuviCloudApiSettingString
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: humidityUnit)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    func set(pressureUnit: UnitPressure) -> Future<UnitPressure, RuuviCloudError> {
        let promise = Promise<UnitPressure, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .unitPressure,
            value: pressureUnit.ruuviCloudApiSettingString
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: pressureUnit)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    func getCloudSettings() -> Future<RuuviCloudSettings, RuuviCloudError> {
        let promise = Promise<RuuviCloudSettings, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiGetSettingsRequest()
        api.getSettings(request, authorization: apiKey)
            .on(success: { response in
                promise.succeed(value: response.settings)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    func resetImage(
        for macId: MACIdentifier
    ) -> Future<Void, RuuviCloudError> {
        let promise = Promise<Void, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiSensorImageUploadRequest(
            sensor: macId.value,
            action: .reset
        )
        api.resetImage(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: ())
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) -> Future<URL, RuuviCloudError> {
        let promise = Promise<URL, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let requestModel = RuuviCloudApiSensorImageUploadRequest(
            sensor: macId.value,
            action: .upload,
            mimeType: mimeType
        )
        api.uploadImage(
            requestModel,
            imageData: imageData,
            authorization: apiKey,
            uploadProgress: { percentage in
                progress?(macId, percentage)
            }).on(success: { response in
                promise.succeed(value: response.uploadURL)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensor, RuuviCloudError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiSensorUpdateRequest(
            sensor: sensor.id,
            name: sensor.name,
            offsetTemperature: temperatureOffset,
            offsetHumidity: humidityOffset,
            offsetPressure: pressureOffset

        )
        api.update(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: sensor.any)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    func update(
        name: String,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensor, RuuviCloudError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiSensorUpdateRequest(
            sensor: sensor.id,
            name: name,
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil

        )
        api.update(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: sensor.with(name: name).any)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    func loadShared(for sensor: RuuviTagSensor) -> Future<Set<AnyShareableSensor>, RuuviCloudError> {
        let promise = Promise<Set<AnyShareableSensor>, RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiGetSensorsRequest(sensor: sensor.id)
        api.sensors(request, authorization: apiKey)
            .on(success: { response in
                let arrayOfAny = response.sensors.map({ $0.shareableSensor.any })
                let setOfAny = Set<AnyShareableSensor>(arrayOfAny)
                promise.succeed(value: setOfAny)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
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

    func loadSensors() -> Future<[AnyCloudSensor], RuuviCloudError> {
        let promise = Promise<[AnyCloudSensor], RuuviCloudError>()
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        api.user(authorization: apiKey).on(success: { response in
            let email = response.email
            let sensors = response.sensors.map({ $0.with(email: email).any })
            promise.succeed(value: sensors)
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
        loadRecordsByChunk(
            macId: macId,
            since: since,
            until: until,
            records: [],
            chunkSize: 5000, // TODO: @rinat replace with setting
            promise: promise
        )
        return promise.future
    }

    private var apiKey: String?
    private let api: RuuviCloudApi

    // swiftlint:disable:next function_parameter_count
    private func loadRecordsByChunk(
        macId: MACIdentifier,
        since: Date,
        until: Date?,
        records: [AnyRuuviTagSensorRecord],
        chunkSize: Int,
        promise: Promise<[AnyRuuviTagSensorRecord], RuuviCloudError>
    ) {
        guard let apiKey = apiKey else {
            promise.fail(error: .notAuthorized)
            return
        }
        let request = RuuviCloudApiGetSensorRequest(
            sensor: macId.value,
            until: until?.timeIntervalSince1970,
            since: since.timeIntervalSince1970,
            limit: chunkSize,
            sort: .asc
        )
        api.getSensorData(request, authorization: apiKey)
            .on(success: { [weak self] response in
                guard let sSelf = self else { return }
                let fetchedRecords = sSelf.decodeSensorRecords(macId: macId, response: response)
                if let lastRecord = fetchedRecords.last,
                   !records.contains(lastRecord),
                   lastRecord.date < until ?? Date.distantFuture {
                    sSelf.loadRecordsByChunk(
                        macId: macId,
                        since: lastRecord.date,
                        until: until,
                        records: records + fetchedRecords,
                        chunkSize: chunkSize,
                        promise: promise
                    )
                } else {
                    promise.succeed(value: records + fetchedRecords)
                }
            }, failure: { (error) in
                promise.fail(error: .api(error))
            })
    }

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
// swiftlint:enable file_length
