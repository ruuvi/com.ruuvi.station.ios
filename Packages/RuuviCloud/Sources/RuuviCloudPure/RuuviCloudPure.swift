// swiftlint:disable file_length
import Foundation
import Future
import RuuviOntology
import BTKit
import RuuviUser
import RuuviCloud
import RuuviPool
#if canImport(RuuviCloudApi)
import RuuviCloudApi
#endif

// swiftlint:disable:next type_body_length
public final class RuuviCloudPure: RuuviCloud {
    private let user: RuuviUser
    private let api: RuuviCloudApi
    private let pool: RuuviPool?

    public init(api: RuuviCloudApi,
                user: RuuviUser,
                pool: RuuviPool?) {
        self.api = api
        self.user = user
        self.pool = pool
    }

    @discardableResult
    public func loadAlerts() -> Future<[RuuviCloudSensorAlerts], RuuviCloudError> {
        let promise = Promise<[RuuviCloudSensorAlerts], RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiGetAlertsRequest()
        api.getAlerts(request, authorization: apiKey)
            .on(success: { response in
                promise.succeed(value: response.sensors)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    // swiftlint:disable:next function_parameter_count
    public func setAlert(
        type: RuuviCloudAlertType,
        settingType: RuuviCloudAlertSettingType,
        isEnabled: Bool,
        min: Double?,
        max: Double?,
        counter: Int?,
        description: String?,
        for macId: MACIdentifier
    ) -> Future<Void, RuuviCloudError> {
        let promise = Promise<Void, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostAlertRequest(
            sensor: macId.value,
            enabled: isEnabled,
            type: type,
            min: min,
            max: max,
            description: description,
            counter: counter
        )
        api.postAlert(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: ())
            }, failure: { [weak self] error in
                let uniqueKey = macId.value + "-" + type.rawValue + "-" + settingType.rawValue
                self?.createQueuedRequest(
                    from: request,
                    type: .alert,
                    uniqueKey: uniqueKey
                )

                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(temperatureUnit: TemperatureUnit) -> Future<TemperatureUnit, RuuviCloudError> {
        let promise = Promise<TemperatureUnit, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
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
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.unitTemperature.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(temperatureAccuracy: MeasurementAccuracyType) -> Future<MeasurementAccuracyType, RuuviCloudError> {
        let promise = Promise<MeasurementAccuracyType, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .accuracyTemperature,
            value: temperatureAccuracy.value.ruuviCloudApiSettingString
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: temperatureAccuracy)
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.accuracyTemperature.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(humidityUnit: HumidityUnit) -> Future<HumidityUnit, RuuviCloudError> {
        let promise = Promise<HumidityUnit, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
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
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.unitHumidity.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(humidityAccuracy: MeasurementAccuracyType) -> Future<MeasurementAccuracyType, RuuviCloudError> {
        let promise = Promise<MeasurementAccuracyType, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .accuracyHumidity,
            value: humidityAccuracy.value.ruuviCloudApiSettingString
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: humidityAccuracy)
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.accuracyHumidity.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(pressureUnit: UnitPressure) -> Future<UnitPressure, RuuviCloudError> {
        let promise = Promise<UnitPressure, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
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
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.unitPressure.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(pressureAccuracy: MeasurementAccuracyType) -> Future<MeasurementAccuracyType, RuuviCloudError> {
        let promise = Promise<MeasurementAccuracyType, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .accuracyPressure,
            value: pressureAccuracy.value.ruuviCloudApiSettingString
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: pressureAccuracy)
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.accuracyPressure.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(showAllData: Bool) -> Future<Bool, RuuviCloudError> {
        let promise = Promise<Bool, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartShowAllPoints,
            value: showAllData.chartBoolSettingString
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: showAllData)
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.chartShowAllPoints.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(drawDots: Bool) -> Future<Bool, RuuviCloudError> {
        let promise = Promise<Bool, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartDrawDots,
            value: drawDots.chartBoolSettingString
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: drawDots)
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.chartDrawDots.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(chartDuration: Int) -> Future<Int, RuuviCloudError> {
        let promise = Promise<Int, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartViewPeriod,
            value: chartDuration.ruuviCloudApiSettingString
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: chartDuration)
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.chartViewPeriod.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(cloudMode: Bool) -> Future<Bool, RuuviCloudError> {
        let promise = Promise<Bool, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .cloudModeEnabled,
            value: cloudMode.chartBoolSettingString
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: cloudMode)
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.cloudModeEnabled.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(dashboard: Bool) -> Future<Bool, RuuviCloudError> {
        let promise = Promise<Bool, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardEnabled,
            value: dashboard.chartBoolSettingString
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: dashboard)
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.dashboardEnabled.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(dashboardType: DashboardType) -> Future<DashboardType, RuuviCloudError> {
        let promise = Promise<DashboardType, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardType,
            value: dashboardType.rawValue
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: dashboardType)
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.dashboardType.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func set(dashboardTapActionType: DashboardTapActionType) ->
        Future<DashboardTapActionType, RuuviCloudError> {
        let promise = Promise<DashboardTapActionType, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardTapActionType,
            value: dashboardTapActionType.rawValue
        )
        api.postSetting(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: dashboardTapActionType)
            }, failure: { [weak self] error in
                self?.createQueuedRequest(
                    from: request,
                    type: .settings,
                    uniqueKey: RuuviCloudApiSetting.dashboardTapActionType.rawValue
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    @discardableResult
    public func getCloudSettings() -> Future<RuuviCloudSettings, RuuviCloudError> {
        let promise = Promise<RuuviCloudSettings, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
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
    public func resetImage(
        for macId: MACIdentifier
    ) -> Future<Void, RuuviCloudError> {
        let promise = Promise<Void, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
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

    public func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) -> Future<URL, RuuviCloudError> {
        let promise = Promise<URL, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
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
            }, failure: { [weak self] error in
                let uniqueKey = macId.value + "-uploadImage"
                self?.createQueuedRequest(
                    from: requestModel,
                    additionalData: imageData,
                    type: .uploadImage,
                    uniqueKey: uniqueKey
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    public func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensor, RuuviCloudError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
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
            }, failure: { [weak self] error in

                var keySuffix: String = ""
                if temperatureOffset != nil {
                    keySuffix = "-temperatureOffset"
                } else if humidityOffset != nil {
                    keySuffix = "-humidityOffset"
                } else if pressureOffset != nil {
                    keySuffix = "-pressureOffset"
                }
                let uniqueKey = sensor.id + keySuffix

                self?.createQueuedRequest(
                    from: request,
                    type: .sensor,
                    uniqueKey: uniqueKey
                )

                promise.fail(error: .api(error))
            })
        return promise.future
    }

    public func update(
        name: String,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensor, RuuviCloudError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
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
            }, failure: { [weak self] error in
                let uniqueKey = sensor.id + "-name"
                self?.createQueuedRequest(
                    from: request,
                    type: .sensor,
                    uniqueKey: uniqueKey
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    public func loadShared(for sensor: RuuviTagSensor) -> Future<Set<AnyShareableSensor>, RuuviCloudError> {
        let promise = Promise<Set<AnyShareableSensor>, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
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

    @discardableResult
    public func checkOwner(macId: MACIdentifier) -> Future<String, RuuviCloudError> {
        let promise = Promise<String, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiGetSensorsRequest(sensor: macId.mac)
        api.owner(request, authorization: apiKey)
            .on(success: { response in
                promise.succeed(value: response.email)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    public func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?
    ) -> Future<[RuuviCloudSensorDense], RuuviCloudError> {
        let promise = Promise<[RuuviCloudSensorDense], RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiGetSensorsDenseRequest(
            sensor: sensor?.id,
            measurements: measurements,
            sharedToMe: sharedToMe,
            sharedToOthers: sharedToOthers,
            alerts: alerts
        )
        api.sensorsDense(request, authorization: apiKey)
            .on(success: { [weak self] response in
                let arrayOfAny = response.sensors.compactMap({ sensor in
                    RuuviCloudSensorDense(
                        sensor: CloudSensorStruct(
                            id: sensor.sensor,
                            name: sensor.name,
                            isClaimed: true,
                            isOwner: sensor.owner == self?.user.email,
                            owner: sensor.owner,
                            picture: URL(string: sensor.picture),
                            offsetTemperature: sensor.offsetTemperature,
                            offsetHumidity: sensor.offsetHumidity,
                            offsetPressure: sensor.offsetPressure,
                            isCloudSensor: true,
                            canShare: sensor.canShare,
                            sharedTo: sensor.sharedTo ?? []
                        ),
                        record: self?.decodeSensorRecord(
                            macId: sensor.sensor.mac,
                            record: sensor.lastMeasurement
                        ),
                        alerts: sensor.alerts,
                        subscription: sensor.subscription
                    )
                })
                promise.succeed(value: arrayOfAny)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    public func share(macId: MACIdentifier, with email: String) -> Future<MACIdentifier, RuuviCloudError> {
        let promise = Promise<MACIdentifier, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
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

    public func unshare(macId: MACIdentifier, with email: String?) -> Future<MACIdentifier, RuuviCloudError> {
        let promise = Promise<MACIdentifier, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
        api.unshare(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: macId)
            }, failure: { [weak self] error in
                guard let email = email else {
                    promise.fail(error: .api(error))
                    return
                }
                let uniqueKey = macId.mac + "-unshare-" + email
                self?.createQueuedRequest(
                    from: request,
                    type: .unshare,
                    uniqueKey: uniqueKey
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    public func claim(
        name: String,
        macId: MACIdentifier
    ) -> Future<MACIdentifier, RuuviCloudError> {
        let promise = Promise<MACIdentifier, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiClaimRequest(name: name, sensor: macId.value)
        api.claim(request, authorization: apiKey)
            .on(success: { response in
                promise.succeed(value: response.sensor.mac)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    public func unclaim(macId: MACIdentifier) -> Future<MACIdentifier, RuuviCloudError> {
        let promise = Promise<MACIdentifier, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiClaimRequest(name: nil, sensor: macId.value)
        api.unclaim(request, authorization: apiKey)
            .on(success: { _ in
                promise.succeed(value: macId)
            }, failure: { [weak self] error in
                let uniqueKey = macId.mac + "-unclaim"
                self?.createQueuedRequest(
                    from: request,
                    type: .unclaim,
                    uniqueKey: uniqueKey
                )
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    public func requestCode(email: String) -> Future<String, RuuviCloudError> {
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

    public func validateCode(code: String) -> Future<ValidateCodeResponse, RuuviCloudError> {
        let promise = Promise<ValidateCodeResponse, RuuviCloudError>()
        let request = RuuviCloudApiVerifyRequest(token: code)
        api.verify(request)
            .on(success: { response in
                let result = ValidateCodeResponse(
                    email: response.email,
                    apiKey: response.accessToken
                )
                promise.succeed(value: result)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    public func deleteAccount(email: String) -> Future<Bool, RuuviCloudError> {
        let promise = Promise<Bool, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudApiAccountDeleteRequest(email: email)
        api.deleteAccount(request,
                          authorization: apiKey)
            .on(success: { response in
                promise.succeed(value: response.email == email)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    public func registerPNToken(token: String,
                                type: String,
                                name: String?,
                                data: String?) -> Future<Int, RuuviCloudError> {
        let promise = Promise<Int, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudPNTokenRegisterRequest(token: token,
                                                       type: type,
                                                       name: name,
                                                       data: data)
        api.registerPNToken(request,
                          authorization: apiKey)
            .on(success: { response in
                promise.succeed(value: response.id)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    public func unregisterPNToken(token: String?,
                                  tokenId: Int?) -> Future<Bool, RuuviCloudError> {
        let promise = Promise<Bool, RuuviCloudError>()
        let request = RuuviCloudPNTokenUnregisterRequest(token: token,
                                                         id: tokenId)
        api.unregisterPNToken(request,
                              authorization: user.apiKey)
            .on(success: { _ in
                promise.succeed(value: true)
            }, failure: { error in
                promise.fail(error: .api(error))
            })
        return promise.future
    }

    public func listPNTokens() -> Future<[RuuviCloudPNToken], RuuviCloudError> {
        let promise = Promise<[RuuviCloudPNToken], RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        let request = RuuviCloudPNTokenListRequest()
        api.listPNTokens(request,
                         authorization: apiKey).on(success: { response in
            let tokens = response.anyTokens
            promise.succeed(value: tokens)
        }, failure: { error in
            promise.fail(error: .api(error))
        })
        return promise.future
    }

    public func loadSensors() -> Future<[AnyCloudSensor], RuuviCloudError> {
        let promise = Promise<[AnyCloudSensor], RuuviCloudError>()
        guard let apiKey = user.apiKey else {
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
    public func loadRecords(
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

    // swiftlint:disable:next function_parameter_count
    private func loadRecordsByChunk(
        macId: MACIdentifier,
        since: Date,
        until: Date?,
        records: [AnyRuuviTagSensorRecord],
        chunkSize: Int,
        promise: Promise<[AnyRuuviTagSensorRecord], RuuviCloudError>
    ) {
        guard let apiKey = user.apiKey else {
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
                // Offset is to check whether we have recent minute data. (Current time + 1 min)
                let offset = Date().addingTimeInterval(1 * 60)
                if let lastRecord = fetchedRecords.last,
                   !records.contains(lastRecord) {
                    let loadable =
                        (until != nil && lastRecord.date < until!) || lastRecord.date > offset
                    if loadable {
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
                } else {
                    promise.succeed(value: records + fetchedRecords)
                }
            }, failure: { (error) in
                promise.fail(error: .api(error))
            })
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    public func executeQueuedRequest(from request: RuuviCloudQueuedRequest)
    -> Future<Bool, RuuviCloudError> {
        let promise = Promise<Bool, RuuviCloudError>()
        guard let apiKey = user.apiKey else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }

        guard let type = request.type, let requestBody = request.requestBodyData else {
            promise.fail(error: .api(.unexpectedHTTPStatusCode))
            return promise.future
        }

        let decoder = JSONDecoder()
        switch type {
        case .sensor:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiSensorUpdateRequest.self,
                    from: requestBody
                )

                api.update(request, authorization: apiKey)
                    .on(success: { _ in
                        promise.succeed(value: true)
                    }, failure: { error in
                        promise.fail(error: .api(error))
                    })
            } catch {
                promise.fail(error: .api(.parsing(error)))
            }
        case .unclaim:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiClaimRequest.self,
                    from: requestBody
                )

                api.unclaim(request, authorization: apiKey)
                    .on(success: { _ in
                        promise.succeed(value: true)
                    }, failure: { error in
                        promise.fail(error: .api(error))
                    })
            } catch {
                promise.fail(error: .api(.parsing(error)))
            }
        case .unshare:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiShareRequest.self,
                    from: requestBody
                )

                api.unshare(request, authorization: apiKey)
                    .on(success: { _ in
                        promise.succeed(value: true)
                    }, failure: { error in
                        promise.fail(error: .api(error))
                    })
            } catch {
                promise.fail(error: .api(.parsing(error)))
            }
        case .alert:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiPostAlertRequest.self,
                    from: requestBody
                )

                api.postAlert(request, authorization: apiKey)
                    .on(success: { _ in
                        promise.succeed(value: true)
                    }, failure: { error in
                        promise.fail(error: .api(error))
                    })
            } catch {
                promise.fail(error: .api(.parsing(error)))
            }
        case .settings:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiPostSettingRequest.self,
                    from: requestBody
                )

                api.postSetting(request, authorization: apiKey)
                    .on(success: { _ in
                        promise.succeed(value: true)
                    }, failure: { error in
                        promise.fail(error: .api(error))
                    })
            } catch {
                promise.fail(error: .api(.parsing(error)))
            }
        case .uploadImage:
            do {
                guard let imageData = request.additionalData else {
                    return promise.future
                }

                let requestModel = try decoder.decode(
                    RuuviCloudApiSensorImageUploadRequest.self,
                    from: requestBody
                )

                api.uploadImage(
                    requestModel,
                    imageData: imageData,
                    authorization: apiKey,
                    uploadProgress: nil
                )
                .on(success: { _ in
                    promise.succeed(value: true)
                }, failure: { error in
                    promise.fail(error: .api(error))
                })
            } catch {
                promise.fail(error: .api(.parsing(error)))
            }
        default:
            break
        }
        return promise.future
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
                luid: nil,
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

    private func decodeSensorRecord(
        macId: MACIdentifier,
        record: UserApiSensorRecord?
    ) -> AnyRuuviTagSensorRecord? {
        let decoder = Ruuvi.decoder
        guard let record = record,
                let device = decoder.decodeNetwork(
                uuid: macId.value,
                rssi: record.rssi,
                isConnectable: true,
                payload: record.data
        ),
        let tag = device.ruuvi?.tag else {
            return nil
        }
        return RuuviTagSensorRecordStruct(
            luid: nil,
            date: record.date,
            source: .ruuviNetwork,
            macId: macId,
            rssi: record.rssi,
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
    }

    private func createQueuedRequest(from request: Codable,
                                     additionalData: Data? = nil,
                                     type: RuuviCloudQueuedRequestType,
                                     uniqueKey: String) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(request) else {
            return
        }
        let request = RuuviCloudQueuedRequestStruct(
            id: nil,
            type: type,
            status: .failed,
            uniqueKey: uniqueKey,
            requestDate: Date(),
            successDate: nil,
            attempts: 1,
            requestBodyData: data,
            additionalData: additionalData
        )
        pool?.createQueuedRequest(request)
    }
}
// swiftlint:enable file_length
