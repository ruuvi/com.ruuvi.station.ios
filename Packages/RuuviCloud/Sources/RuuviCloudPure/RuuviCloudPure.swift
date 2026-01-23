import BTKit
// swiftlint:disable file_length
import Foundation
import RuuviOntology
import RuuviPool
import RuuviUser

// swiftlint:disable:next type_body_length
public actor RuuviCloudPure: RuuviCloud {
    private let user: RuuviUser
    private let api: RuuviCloudApi
    private let pool: RuuviPool?

    public init(
        api: RuuviCloudApi,
        user: RuuviUser,
        pool: RuuviPool?
    ) {
        self.api = api
        self.user = user
        self.pool = pool
    }

    @discardableResult
    public func loadAlerts() async throws -> [RuuviCloudSensorAlerts] {
        let apiKey = try apiKey()
        let request = RuuviCloudApiGetAlertsRequest()
        do {
            let response = try await api.getAlerts(request, authorization: apiKey)
            return response.sensors ?? []
        } catch {
            throw wrapApiError(error)
        }
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
        delay: Int?,
        description: String?,
        for macId: MACIdentifier
    ) async throws -> Void {
        notifyListener(state: .loading, macId: macId.mac)
        defer {
            notifyListener(state: .complete, macId: macId.mac)
        }
        guard let apiKey = user.apiKey else {
            notifyListener(state: .failed, macId: macId.mac)
            throw RuuviCloudError.notAuthorized
        }
        let request = RuuviCloudApiPostAlertRequest(
            sensor: macId.value,
            enabled: isEnabled,
            type: type,
            min: min,
            max: max,
            description: description,
            counter: counter,
            delay: delay,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postAlert(request, authorization: apiKey)
            notifyListener(state: .success, macId: macId.mac)
        } catch {
            let uniqueKey = macId.value + "-" + type.rawValue + "-" + settingType.rawValue
            await createQueuedRequest(
                from: request,
                type: .alert,
                uniqueKey: uniqueKey
            )
            notifyListener(state: .failed, macId: macId.mac)
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(temperatureUnit: TemperatureUnit) async throws -> TemperatureUnit {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .unitTemperature,
            value: temperatureUnit.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return temperatureUnit
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.unitTemperature.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(temperatureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .accuracyTemperature,
            value: temperatureAccuracy.value.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return temperatureAccuracy
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.accuracyTemperature.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .unitHumidity,
            value: humidityUnit.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return humidityUnit
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.unitHumidity.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(humidityAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .accuracyHumidity,
            value: humidityAccuracy.value.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return humidityAccuracy
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.accuracyHumidity.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(pressureUnit: UnitPressure) async throws -> UnitPressure {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .unitPressure,
            value: pressureUnit.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return pressureUnit
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.unitPressure.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(pressureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .accuracyPressure,
            value: pressureAccuracy.value.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return pressureAccuracy
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.accuracyPressure.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(showAllData: Bool) async throws -> Bool {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartShowAllPoints,
            value: showAllData.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return showAllData
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.chartShowAllPoints.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(drawDots: Bool) async throws -> Bool {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartDrawDots,
            value: drawDots.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return drawDots
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.chartDrawDots.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(chartDuration: Int) async throws -> Int {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartViewPeriod,
            value: chartDuration.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return chartDuration
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.chartViewPeriod.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(showMinMaxAvg: Bool) async throws -> Bool {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartShowMinMaxAverage,
            value: showMinMaxAvg.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return showMinMaxAvg
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.chartShowMinMaxAverage.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(cloudMode: Bool) async throws -> Bool {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .cloudModeEnabled,
            value: cloudMode.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return cloudMode
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.cloudModeEnabled.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(dashboard: Bool) async throws -> Bool {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardEnabled,
            value: dashboard.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return dashboard
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.dashboardEnabled.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(dashboardType: DashboardType) async throws -> DashboardType {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardType,
            value: dashboardType.rawValue,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return dashboardType
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.dashboardType.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(dashboardTapActionType: DashboardTapActionType) async throws -> DashboardTapActionType {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardTapActionType,
            value: dashboardTapActionType.rawValue,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return dashboardTapActionType
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.dashboardTapActionType.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(disableEmailAlert: Bool) async throws -> Bool {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .emailAlertDisabled,
            value: disableEmailAlert.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return disableEmailAlert
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.emailAlertDisabled.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(disablePushAlert: Bool) async throws -> Bool {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .pushAlertDisabled,
            value: disablePushAlert.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return disablePushAlert
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.pushAlertDisabled.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(profileLanguageCode: String) async throws -> String {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .profileLanguageCode,
            value: profileLanguageCode,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return profileLanguageCode
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.profileLanguageCode.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func set(dashboardSensorOrder: [String]) async throws -> [String] {
        let apiKey = try apiKey()
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardSensorOrder,
            value: RuuviCloudApiHelper.jsonStringFromArray(dashboardSensorOrder),
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return dashboardSensorOrder
        } catch {
            await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.dashboardSensorOrder.rawValue
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func getCloudSettings() async throws -> RuuviCloudSettings? {
        let apiKey = try apiKey()
        let request = RuuviCloudApiGetSettingsRequest()
        do {
            let response = try await api.getSettings(request, authorization: apiKey)
            return response.settings
        } catch {
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func resetImage(
        for macId: MACIdentifier
    ) async throws -> Void {
        let apiKey = try apiKey()
        let request = RuuviCloudApiSensorImageUploadRequest(
            sensor: macId.value,
            action: .reset
        )
        do {
            _ = try await api.resetImage(request, authorization: apiKey)
        } catch {
            throw wrapApiError(error)
        }
    }

    public func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws -> URL {
        let apiKey = try apiKey()
        let requestModel = RuuviCloudApiSensorImageUploadRequest(
            sensor: macId.value,
            action: .upload,
            mimeType: mimeType
        )
        do {
            let response = try await api.uploadImage(
                requestModel,
                imageData: imageData,
                authorization: apiKey,
                uploadProgress: { percentage in
                    progress?(macId, percentage)
                }
            )
            return response.uploadURL
        } catch {
            let uniqueKey = macId.value + "-uploadImage"
            await createQueuedRequest(
                from: requestModel,
                additionalData: imageData,
                type: .uploadImage,
                uniqueKey: uniqueKey
            )
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws -> AnyRuuviTagSensor {
        let apiKey = try apiKey()

        guard types.count == values.count else {
            throw RuuviCloudError.api(.badParameters)
        }

        let request = RuuviCloudApiPostSensorSettingsRequest(
            sensor: sensor.id,
            type: types,
            value: values,
            timestamp: timestamp ?? Int(Date().timeIntervalSince1970)
        )

        do {
            _ = try await api.postSensorSettings(request, authorization: apiKey)
            return sensor.any
        } catch {
            await createQueuedRequest(
                from: request,
                type: .sensorSettings,
                uniqueKey: sensor.id + "-sensor-settings"
            )
            throw wrapApiError(error)
        }
    }

    public func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor {
        let apiKey = try apiKey()
        let request = RuuviCloudApiSensorUpdateRequest(
            sensor: sensor.id,
            name: sensor.name,
            offsetTemperature: temperatureOffset,
            offsetHumidity: humidityOffset,
            offsetPressure: pressureOffset,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.update(request, authorization: apiKey)
            return sensor.any
        } catch {
            var keySuffix: String = ""
            if temperatureOffset != nil {
                keySuffix = "-temperatureOffset"
            } else if humidityOffset != nil {
                keySuffix = "-humidityOffset"
            } else if pressureOffset != nil {
                keySuffix = "-pressureOffset"
            }
            let uniqueKey = sensor.id + keySuffix

            await createQueuedRequest(
                from: request,
                type: .sensor,
                uniqueKey: uniqueKey
            )

            throw wrapApiError(error)
        }
    }

    public func update(
        name: String,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor {
        notifyListener(state: .loading, macId: sensor.id)
        defer {
            notifyListener(state: .complete, macId: sensor.id)
        }
        guard let apiKey = user.apiKey else {
            notifyListener(state: .failed, macId: sensor.id)
            throw RuuviCloudError.notAuthorized
        }
        let request = RuuviCloudApiSensorUpdateRequest(
            sensor: sensor.id,
            name: name,
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.update(request, authorization: apiKey)
            notifyListener(state: .success, macId: sensor.id)
            return sensor.with(name: name).any
        } catch {
            let uniqueKey = sensor.id + "-name"
            await createQueuedRequest(
                from: request,
                type: .sensor,
                uniqueKey: uniqueKey
            )
            notifyListener(state: .failed, macId: sensor.id)
            throw wrapApiError(error)
        }
    }

    public func loadShared(for sensor: RuuviTagSensor) async throws -> Set<AnyShareableSensor> {
        let apiKey = try apiKey()
        let request = RuuviCloudApiGetSensorsRequest(sensor: sensor.id)
        do {
            let response = try await api.sensors(request, authorization: apiKey)
            let arrayOfAny = response.sensors?.map(\.shareableSensor.any)
            return Set<AnyShareableSensor>(arrayOfAny ?? [])
        } catch {
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func checkOwner(macId: MACIdentifier) async throws -> (String?, String?) {
        let apiKey = try apiKey()
        let request = RuuviCloudApiGetSensorsRequest(sensor: macId.mac)
        do {
            let response = try await api.owner(request, authorization: apiKey)
            return (response.email, response.sensor)
        } catch {
            throw wrapApiError(error)
        }
    }

    // swiftlint:disable:next function_parameter_count function_body_length
    public func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) async throws -> [RuuviCloudSensorDense] {
        let apiKey = try apiKey()
        let request = RuuviCloudApiGetSensorsDenseRequest(
            sensor: sensor?.id,
            measurements: measurements,
            sharedToMe: sharedToMe,
            sharedToOthers: sharedToOthers,
            alerts: alerts,
            settings: settings
        )
        do {
            let response = try await api.sensorsDense(request, authorization: apiKey)
            let arrayOfAny = response.sensors?.compactMap { sensor in
                RuuviCloudSensorDense(
                    sensor: CloudSensorStruct(
                        id: sensor.sensor,
                        serviceUUID: nil,
                        name: sensor.name,
                        isClaimed: true,
                        isOwner: sensor.owner == user.email,
                        owner: sensor.owner,
                        ownersPlan: sensor.subscription?.subscriptionName,
                        picture: URL(string: sensor.picture),
                        offsetTemperature: sensor.offsetTemperature,
                        offsetHumidity: sensor.offsetHumidity,
                        offsetPressure: sensor.offsetPressure,
                        isCloudSensor: true,
                        canShare: sensor.canShare,
                        sharedTo: sensor.sharedTo ?? [],
                        maxHistoryDays: sensor.subscription?.maxHistoryDays
                    ),
                    record: decodeSensorRecord(
                        macId: sensor.sensor.mac,
                        record: sensor.lastMeasurement
                    ),
                    alerts: sensor.alerts,
                    subscription: sensor.subscription,
                    settings: sensor.settings.map {
                        RuuviCloudSensorSettings(
                            displayOrderCodes: $0.displayOrderCodes,
                            defaultDisplayOrder: $0.defaultDisplayOrder
                        )
                    }
                )
            }
            return arrayOfAny ?? []
        } catch {
            throw wrapApiError(error)
        }
    }

    public func share(macId: MACIdentifier, with email: String) async throws -> ShareSensorResponse {
        let apiKey = try apiKey()
        let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
        do {
            let response = try await api.share(request, authorization: apiKey)
            return ShareSensorResponse(
                macId: response.sensor?.mac,
                invited: response.invited
            )
        } catch {
            throw wrapApiError(error)
        }
    }

    public func unshare(macId: MACIdentifier, with email: String?) async throws -> MACIdentifier {
        let apiKey = try apiKey()
        let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
        do {
            _ = try await api.unshare(request, authorization: apiKey)
            return macId
        } catch {
            if let email {
                let uniqueKey = macId.mac + "-unshare-" + email
                await createQueuedRequest(
                    from: request,
                    type: .unshare,
                    uniqueKey: uniqueKey
                )
            }
            throw wrapApiError(error)
        }
    }

    public func claim(
        name: String,
        macId: MACIdentifier
    ) async throws -> MACIdentifier? {
        let apiKey = try apiKey()
        let request = RuuviCloudApiClaimRequest(name: name, sensor: macId.value)
        do {
            let response = try await api.claim(request, authorization: apiKey)
            return response.sensor?.mac
        } catch {
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func contest(
        macId: MACIdentifier,
        secret: String
    ) async throws -> MACIdentifier? {
        let apiKey = try apiKey()
        let request = RuuviCloudApiContestRequest(sensor: macId.value, secret: secret)
        do {
            let response = try await api.contest(request, authorization: apiKey)
            return response.sensor?.mac
        } catch {
            throw wrapApiError(error)
        }
    }

    public func unclaim(
        macId: MACIdentifier,
        removeCloudHistory: Bool
    ) async throws -> MACIdentifier {
        let apiKey = try apiKey()
        let request = RuuviCloudApiUnclaimRequest(
            sensor: macId.value,
            deleteData: removeCloudHistory
        )
        do {
            _ = try await api.unclaim(request, authorization: apiKey)
            return macId
        } catch {
            let uniqueKey = macId.mac + "-unclaim"
            await createQueuedRequest(
                from: request,
                type: .unclaim,
                uniqueKey: uniqueKey
            )
            throw wrapApiError(error)
        }
    }

    public func requestCode(email: String) async throws -> String? {
        let request = RuuviCloudApiRegisterRequest(email: email)
        do {
            let response = try await api.register(request)
            return response.email
        } catch {
            throw wrapApiError(error)
        }
    }

    public func validateCode(code: String) async throws -> ValidateCodeResponse {
        let request = RuuviCloudApiVerifyRequest(token: code)
        do {
            let response = try await api.verify(request)
            guard let email = response.email,
                  let accessToken = response.accessToken
            else {
                throw RuuviCloudError.api(.api(.erInternal))
            }
            return ValidateCodeResponse(
                email: email,
                apiKey: accessToken
            )
        } catch {
            throw wrapApiError(error)
        }
    }

    public func deleteAccount(email: String) async throws -> Bool {
        let apiKey = try apiKey()
        let request = RuuviCloudApiAccountDeleteRequest(email: email)
        do {
            let response = try await api.deleteAccount(
                request,
                authorization: apiKey
            )
            return response.email == email
        } catch {
            throw wrapApiError(error)
        }
    }

    public func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws -> Int {
        let apiKey = try apiKey()
        let request = RuuviCloudPNTokenRegisterRequest(
            token: token,
            type: type,
            name: name,
            data: data,
            params: params
        )
        do {
            let response = try await api.registerPNToken(
                request,
                authorization: apiKey
            )
            return response.id
        } catch {
            throw wrapApiError(error)
        }
    }

    public func unregisterPNToken(
        token: String?,
        tokenId: Int?
    ) async throws -> Bool {
        let request = RuuviCloudPNTokenUnregisterRequest(
            token: token,
            id: tokenId
        )
        do {
            _ = try await api.unregisterPNToken(
                request,
                authorization: user.apiKey
            )
            return true
        } catch {
            throw wrapApiError(error)
        }
    }

    public func listPNTokens() async throws -> [RuuviCloudPNToken] {
        let apiKey = try apiKey()
        let request = RuuviCloudPNTokenListRequest()
        do {
            let response = try await api.listPNTokens(
                request,
                authorization: apiKey
            )
            return response.anyTokens
        } catch {
            throw wrapApiError(error)
        }
    }

    public func loadSensors() async throws -> [AnyCloudSensor] {
        let apiKey = try apiKey()
        do {
            let response = try await api.user(authorization: apiKey)
            let email = response.email
            return response.sensors.map { $0.with(email: email).any }
        } catch {
            throw wrapApiError(error)
        }
    }

    @discardableResult
    public func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws -> [AnyRuuviTagSensorRecord] {
        try await loadRecordsByChunk(
            macId: macId,
            since: since,
            until: until,
            records: [],
            chunkSize: 5000 // TODO: @rinat replace with setting
        )
    }

    // swiftlint:disable:next function_parameter_count
    private func loadRecordsByChunk(
        macId: MACIdentifier,
        since: Date,
        until: Date?,
        records: [AnyRuuviTagSensorRecord],
        chunkSize: Int
    ) async throws -> [AnyRuuviTagSensorRecord] {
        let apiKey = try apiKey()
        let request = RuuviCloudApiGetSensorRequest(
            sensor: macId.value,
            until: until?.timeIntervalSince1970,
            since: since.timeIntervalSince1970,
            limit: chunkSize,
            sort: .asc
        )
        do {
            let response = try await api.getSensorData(request, authorization: apiKey)
            let fetchedRecords = decodeSensorRecords(macId: macId, response: response)
            // Offset is to check whether we have recent minute data. (Current time + 1 min)
            let offset = Date().addingTimeInterval(1 * 60)
            if let lastRecord = fetchedRecords.last,
               !records.contains(lastRecord) {
                let loadable =
                    (until != nil && lastRecord.date < until!) || lastRecord.date > offset
                if loadable {
                    return try await loadRecordsByChunk(
                        macId: macId,
                        since: lastRecord.date,
                        until: until,
                        records: records + fetchedRecords,
                        chunkSize: chunkSize
                    )
                }
            }
            return records + fetchedRecords
        } catch {
            throw wrapApiError(error)
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    public func executeQueuedRequest(from request: RuuviCloudQueuedRequest)
    async throws -> Bool {
        let apiKey = try apiKey()

        guard let type = request.type,
              let requestBody = request.requestBodyData
        else {
            throw RuuviCloudError.api(.badParameters)
        }

        let decoder = JSONDecoder()
        switch type {
        case .sensor:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiSensorUpdateRequest.self,
                    from: requestBody
                )

                _ = try await api.update(request, authorization: apiKey)
                return true
            } catch {
                throw RuuviCloudError.api(.parsing(error))
            }
        case .unclaim:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiUnclaimRequest.self,
                    from: requestBody
                )

                _ = try await api.unclaim(request, authorization: apiKey)
                return true
            } catch {
                throw RuuviCloudError.api(.parsing(error))
            }
        case .unshare:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiShareRequest.self,
                    from: requestBody
                )

                _ = try await api.unshare(request, authorization: apiKey)
                return true
            } catch {
                throw RuuviCloudError.api(.parsing(error))
            }
        case .alert:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiPostAlertRequest.self,
                    from: requestBody
                )

                _ = try await api.postAlert(request, authorization: apiKey)
                return true
            } catch {
                throw RuuviCloudError.api(.parsing(error))
            }
        case .settings:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiPostSettingRequest.self,
                    from: requestBody
                )

                _ = try await api.postSetting(request, authorization: apiKey)
                return true
            } catch {
                throw RuuviCloudError.api(.parsing(error))
            }
        case .sensorSettings:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiPostSensorSettingsRequest.self,
                    from: requestBody
                )

                _ = try await api.postSensorSettings(request, authorization: apiKey)
                return true
            } catch {
                throw RuuviCloudError.api(.parsing(error))
            }
        case .uploadImage:
            do {
                guard let imageData = request.additionalData
                else {
                    throw RuuviCloudError.api(.badParameters)
                }

                let requestModel = try decoder.decode(
                    RuuviCloudApiSensorImageUploadRequest.self,
                    from: requestBody
                )

                _ = try await api.uploadImage(
                    requestModel,
                    imageData: imageData,
                    authorization: apiKey,
                    uploadProgress: nil
                )
                return true
            } catch {
                throw RuuviCloudError.api(.parsing(error))
            }
        default:
            throw RuuviCloudError.api(.badParameters)
        }
    }

    private func decodeSensorRecords(
        macId: MACIdentifier,
        response: RuuviCloudApiGetSensorResponse
    ) -> [AnyRuuviTagSensorRecord] {
        let decoder = Ruuvi.decoder
        guard let measurements = response.measurements
        else {
            return []
        }
        return measurements.compactMap { measurement in
            guard let rssi = measurement.rssi,
                  let data = measurement.data,
                  let device = decoder.decodeNetwork(
                      uuid: macId.value,
                      rssi: rssi,
                      isConnectable: true,
                      payload: data
                  ),
                  let tag = device.ruuvi?.tag
            else {
                return nil
            }
            return RuuviTagSensorRecordStruct(
                luid: nil,
                date: measurement.date,
                source: .ruuviNetwork,
                macId: macId,
                rssi: rssi,
                version: tag.version,
                temperature: tag.temperature,
                humidity: tag.humidity,
                pressure: tag.pressure,
                acceleration: tag.acceleration,
                voltage: tag.voltage,
                movementCounter: tag.movementCounter,
                measurementSequenceNumber: tag.measurementSequenceNumber,
                txPower: tag.txPower,
                pm1: tag.pm1,
                pm25: tag.pm25,
                pm4: tag.pm4,
                pm10: tag.pm10,
                co2: tag.co2,
                voc: tag.voc,
                nox: tag.nox,
                luminance: tag.luminance,
                dbaInstant: tag.dbaInstant,
                dbaAvg: tag.dbaAvg,
                dbaPeak: tag.dbaPeak,
                temperatureOffset: 0.0,
                humidityOffset: 0.0,
                pressureOffset: 0.0
            ).any
        }
    }

    private func decodeSensorRecord(
        macId: MACIdentifier,
        record: UserApiSensorRecord?
    ) -> AnyRuuviTagSensorRecord? {
        let decoder = Ruuvi.decoder
        guard let record,
              let rssi = record.rssi,
              let data = record.data,
              let device = decoder.decodeNetwork(
                  uuid: macId.value,
                  rssi: rssi,
                  isConnectable: true,
                  payload: data
              ),
              let tag = device.ruuvi?.tag
        else {
            return nil
        }
        return RuuviTagSensorRecordStruct(
            luid: nil,
            date: record.date,
            source: .ruuviNetwork,
            macId: macId,
            rssi: record.rssi,
            version: tag.version,
            temperature: tag.temperature,
            humidity: tag.humidity,
            pressure: tag.pressure,
            acceleration: tag.acceleration,
            voltage: tag.voltage,
            movementCounter: tag.movementCounter,
            measurementSequenceNumber: tag.measurementSequenceNumber,
            txPower: tag.txPower,
            pm1: tag.pm1,
            pm25: tag.pm25,
            pm4: tag.pm4,
            pm10: tag.pm10,
            co2: tag.co2,
            voc: tag.voc,
            nox: tag.nox,
            luminance: tag.luminance,
            dbaInstant: tag.dbaInstant,
            dbaAvg: tag.dbaAvg,
            dbaPeak: tag.dbaPeak,
            temperatureOffset: 0.0,
            humidityOffset: 0.0,
            pressureOffset: 0.0
        ).any
    }

    private func apiKey() throws -> String {
        guard let apiKey = user.apiKey else {
            throw RuuviCloudError.notAuthorized
        }
        return apiKey
    }

    private func wrapApiError(_ error: Error) -> RuuviCloudError {
        if let apiError = error as? RuuviCloudApiError {
            return .api(apiError)
        }
        return .api(.networking(error))
    }

    private func createQueuedRequest(
        from request: Codable,
        additionalData: Data? = nil,
        type: RuuviCloudQueuedRequestType,
        uniqueKey: String
    ) async {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(request)
        else {
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
        _ = try? await pool?.createQueuedRequest(request)
    }

    private func notifyListener(
        state: RuuviCloudRequestStateType,
        macId: String
    ) {
        NotificationCenter.default.post(
            name: .RuuviCloudRequestStateDidChange,
            object: nil,
            userInfo: [
                RuuviCloudRequestStateKey.macId: macId,
                RuuviCloudRequestStateKey.state: state,
            ]
        )
    }
}

// swiftlint:enable file_length
