import BTKit
// swiftlint:disable file_length
import Foundation

import RuuviOntology
import RuuviPool
import RuuviUser

// swiftlint:disable:next type_body_length
public final class RuuviCloudPure: RuuviCloud {
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

    public func loadAlerts() async throws -> [RuuviCloudSensorAlerts] {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiGetAlertsRequest()
        let response = try await api.getAlerts(request, authorization: apiKey)
        return response.sensors ?? []
    }

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
    ) async throws {
        notifyListener(state: .loading, macId: macId.mac)
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
            try? await createQueuedRequest(from: request, type: .alert, uniqueKey: uniqueKey)
            notifyListener(state: .failed, macId: macId.mac)
            throw error
        }
        notifyListener(state: .complete, macId: macId.mac)
    }

    public func set(temperatureUnit: TemperatureUnit) async throws -> TemperatureUnit {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .unitTemperature,
            value: temperatureUnit.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.unitTemperature.rawValue
            )
            throw error
        }
        return temperatureUnit
    }

    public func set(temperatureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .accuracyTemperature,
            value: temperatureAccuracy.value.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.accuracyTemperature.rawValue
            )
            throw error
        }
        return temperatureAccuracy
    }

    public func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .unitHumidity,
            value: humidityUnit.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.unitHumidity.rawValue
            )
            throw error
        }
        return humidityUnit
    }

    public func set(humidityAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .accuracyHumidity,
            value: humidityAccuracy.value.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.accuracyHumidity.rawValue
            )
            throw error
        }
        return humidityAccuracy
    }

    public func set(pressureUnit: UnitPressure) async throws -> UnitPressure {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .unitPressure,
            value: pressureUnit.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.unitPressure.rawValue
            )
            throw error
        }
        return pressureUnit
    }

    public func set(pressureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .accuracyPressure,
            value: pressureAccuracy.value.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.accuracyPressure.rawValue
            )
            throw error
        }
        return pressureAccuracy
    }

    public func set(showAllData: Bool) async throws -> Bool {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartShowAllPoints,
            value: showAllData.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.chartShowAllPoints.rawValue
            )
            throw error
        }
        return showAllData
    }

    public func set(drawDots: Bool) async throws -> Bool {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartDrawDots,
            value: drawDots.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.chartDrawDots.rawValue
            )
            throw error
        }
        return drawDots
    }

    public func set(chartDuration: Int) async throws -> Int {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartViewPeriod,
            value: chartDuration.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.chartViewPeriod.rawValue
            )
            throw error
        }
        return chartDuration
    }

    public func set(showMinMaxAvg: Bool) async throws -> Bool {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartShowMinMaxAverage,
            value: showMinMaxAvg.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.chartShowMinMaxAverage.rawValue
            )
            throw error
        }
        return showMinMaxAvg
    }

    public func set(cloudMode: Bool) async throws -> Bool {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .cloudModeEnabled,
            value: cloudMode.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.cloudModeEnabled.rawValue
            )
            throw error
        }
        return cloudMode
    }

    public func set(dashboard: Bool) async throws -> Bool {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardEnabled,
            value: dashboard.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.dashboardEnabled.rawValue
            )
            throw error
        }
        return dashboard
    }

    public func set(dashboardType: DashboardType) async throws -> DashboardType {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardType,
            value: dashboardType.rawValue,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.dashboardType.rawValue
            )
            throw error
        }
        return dashboardType
    }

    public func set(dashboardTapActionType: DashboardTapActionType) async throws -> DashboardTapActionType {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardTapActionType,
            value: dashboardTapActionType.rawValue,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
        } catch {
            try? await createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.dashboardTapActionType.rawValue
            )
            throw error
        }
        return dashboardTapActionType
    }

    public func set(disableEmailAlert: Bool) async throws -> Bool {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .emailAlertDisabled,
            value: disableEmailAlert.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do { _ = try await api.postSetting(request, authorization: apiKey) } catch {
            try? await createQueuedRequest(from: request, type: .settings, uniqueKey: RuuviCloudApiSetting.emailAlertDisabled.rawValue)
            throw error
        }
        return disableEmailAlert
    }

    public func set(disablePushAlert: Bool) async throws -> Bool {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .pushAlertDisabled,
            value: disablePushAlert.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do { _ = try await api.postSetting(request, authorization: apiKey) } catch {
            try? await createQueuedRequest(from: request, type: .settings, uniqueKey: RuuviCloudApiSetting.pushAlertDisabled.rawValue)
            throw error
        }
        return disablePushAlert
    }

    public func set(profileLanguageCode: String) async throws -> String {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .profileLanguageCode,
            value: profileLanguageCode,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do { _ = try await api.postSetting(request, authorization: apiKey) } catch {
            try? await createQueuedRequest(from: request, type: .settings, uniqueKey: RuuviCloudApiSetting.profileLanguageCode.rawValue)
            throw error
        }
        return profileLanguageCode
    }

    public func set(dashboardSensorOrder: [String]) async throws -> [String] {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardSensorOrder,
            value: RuuviCloudApiHelper.jsonStringFromArray(dashboardSensorOrder),
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do { _ = try await api.postSetting(request, authorization: apiKey) } catch {
            try? await createQueuedRequest(from: request, type: .settings, uniqueKey: RuuviCloudApiSetting.dashboardSensorOrder.rawValue)
            throw error
        }
        return dashboardSensorOrder
    }

    public func getCloudSettings() async throws -> RuuviCloudSettings? {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiGetSettingsRequest()
        let response = try await api.getSettings(request, authorization: apiKey)
        return response.settings
    }

    public func resetImage(for macId: MACIdentifier) async throws {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiSensorImageUploadRequest(sensor: macId.value, action: .reset)
        do { _ = try await api.resetImage(request, authorization: apiKey) } catch {
            throw error
        }
    }

    public func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws -> URL {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
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
            try? await createQueuedRequest(
                from: requestModel,
                additionalData: imageData,
                type: .uploadImage,
                uniqueKey: uniqueKey
            )
            throw error
        }
    }

    public func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
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
            if temperatureOffset != nil { keySuffix = "-temperatureOffset" }
            else if humidityOffset != nil { keySuffix = "-humidityOffset" }
            else if pressureOffset != nil { keySuffix = "-pressureOffset" }
            let uniqueKey = sensor.id + keySuffix
            try? await createQueuedRequest(from: request, type: .sensor, uniqueKey: uniqueKey)
            throw error
        }
    }

    public func update(
        name: String,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor {
        notifyListener(state: .loading, macId: sensor.id)
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
            notifyListener(state: .complete, macId: sensor.id)
            return sensor.with(name: name).any
        } catch {
            let uniqueKey = sensor.id + "-name"
            try? await createQueuedRequest(from: request, type: .sensor, uniqueKey: uniqueKey)
            notifyListener(state: .failed, macId: sensor.id)
            notifyListener(state: .complete, macId: sensor.id)
            throw error
        }
    }

    public func loadShared(for sensor: RuuviTagSensor) async throws -> Set<AnyShareableSensor> {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiGetSensorsRequest(sensor: sensor.id)
        let response = try await api.sensors(request, authorization: apiKey)
        let arrayOfAny = response.sensors?.map(\.shareableSensor.any) ?? []
        return Set(arrayOfAny)
    }

    public func checkOwner(macId: MACIdentifier) async throws -> String? {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiGetSensorsRequest(sensor: macId.mac)
        let response = try await api.owner(request, authorization: apiKey)
        return response.email
    }

    public func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?
    ) async throws -> [RuuviCloudSensorDense] {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiGetSensorsDenseRequest(
            sensor: sensor?.id,
            measurements: measurements,
            sharedToMe: sharedToMe,
            sharedToOthers: sharedToOthers,
            alerts: alerts
        )
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
                subscription: sensor.subscription
            )
        } ?? []
        return arrayOfAny
    }

    public func share(macId: MACIdentifier, with email: String) async throws -> ShareSensorResponse {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
        let response = try await api.share(request, authorization: apiKey)
        return ShareSensorResponse(
            macId: response.sensor?.mac,
            invited: response.invited
        )
    }

    public func unshare(macId: MACIdentifier, with email: String?) async throws -> MACIdentifier {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
        do {
            _ = try await api.unshare(request, authorization: apiKey)
            return macId
        } catch {
            if let email { try? await createQueuedRequest(from: request, type: .unshare, uniqueKey: macId.mac + "-unshare-" + email) }
            throw error
        }
    }

    public func claim(name: String, macId: MACIdentifier) async throws -> MACIdentifier? {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiClaimRequest(name: name, sensor: macId.value)
        let response = try await api.claim(request, authorization: apiKey)
        return response.sensor?.mac
    }

    public func contest(macId: MACIdentifier, secret: String) async throws -> MACIdentifier? {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiContestRequest(sensor: macId.value, secret: secret)
        let response = try await api.contest(request, authorization: apiKey)
        return response.sensor?.mac
    }

    public func unclaim(macId: MACIdentifier, removeCloudHistory: Bool) async throws -> MACIdentifier {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiUnclaimRequest(sensor: macId.value, deleteData: removeCloudHistory)
        do {
            _ = try await api.unclaim(request, authorization: apiKey)
            return macId
        } catch {
            let uniqueKey = macId.mac + "-unclaim"
            try? await createQueuedRequest(from: request, type: .unclaim, uniqueKey: uniqueKey)
            throw error
        }
    }

    public func requestCode(email: String) async throws -> String? {
        let request = RuuviCloudApiRegisterRequest(email: email)
        let response = try await api.register(request)
        return response.email
    }

    public func validateCode(code: String) async throws -> ValidateCodeResponse {
        let request = RuuviCloudApiVerifyRequest(token: code)
        let response = try await api.verify(request)
        guard let email = response.email, let accessToken = response.accessToken else {
            throw RuuviCloudError.api(.api(.erInternal))
        }
        return ValidateCodeResponse(email: email, apiKey: accessToken)
    }

    public func deleteAccount(email: String) async throws -> Bool {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudApiAccountDeleteRequest(email: email)
        let response = try await api.deleteAccount(request, authorization: apiKey)
        return response.email == email
    }

    public func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws -> Int {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudPNTokenRegisterRequest(
            token: token,
            type: type,
            name: name,
            data: data,
            params: params
        )
        let response = try await api.registerPNToken(request, authorization: apiKey)
        return response.id
    }

    public func unregisterPNToken(token: String?, tokenId: Int?) async throws -> Bool {
        let request = RuuviCloudPNTokenUnregisterRequest(token: token, id: tokenId)
        do {
            _ = try await api.unregisterPNToken(request, authorization: user.apiKey)
            return true
        } catch { throw error }
    }

    public func listPNTokens() async throws -> [RuuviCloudPNToken] {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let request = RuuviCloudPNTokenListRequest()
        let response = try await api.listPNTokens(request, authorization: apiKey)
        return response.anyTokens
    }

    public func loadSensors() async throws -> [AnyCloudSensor] {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        let response = try await api.user(authorization: apiKey)
        let email = response.email
        return response.sensors.map { $0.with(email: email).any }
    }

    public func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws -> [AnyRuuviTagSensorRecord] {
        // iterative async loop replacing recursive promise style
        var all: [AnyRuuviTagSensorRecord] = []
        var currentSince = since
        let limit = 5000 // TODO: make configurable
        let finalUntil = until
        while true {
            guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
            let request = RuuviCloudApiGetSensorRequest(
                sensor: macId.value,
                until: finalUntil?.timeIntervalSince1970,
                since: currentSince.timeIntervalSince1970,
                limit: limit,
                sort: .asc
            )
            let response = try await api.getSensorData(request, authorization: apiKey)
            let fetched = decodeSensorRecords(macId: macId, response: response)
            if fetched.isEmpty { break }
            // dedupe if overlapping
            for rec in fetched where !all.contains(rec) { all.append(rec) }
            guard let last = fetched.last else { break }
            let offset = Date().addingTimeInterval(60) // 1 min offset
            let loadable = (finalUntil != nil && last.date < finalUntil!) || last.date > offset
            if loadable {
                currentSince = last.date
            } else {
                break
            }
        }
        return all
    }

    // Removed legacy loadRecordsByChunk (Promise-based) after async/await migration.

    public func executeQueuedRequest(from request: RuuviCloudQueuedRequest) async throws -> Bool {
        guard let apiKey = user.apiKey else { throw RuuviCloudError.notAuthorized }
        guard let type = request.type, let requestBody = request.requestBodyData else {
            throw RuuviCloudError.api(.badParameters)
        }
        let decoder = JSONDecoder()
        do {
            switch type {
            case .sensor:
                let model = try decoder.decode(RuuviCloudApiSensorUpdateRequest.self, from: requestBody)
                _ = try await api.update(model, authorization: apiKey)
            case .unclaim:
                let model = try decoder.decode(RuuviCloudApiUnclaimRequest.self, from: requestBody)
                _ = try await api.unclaim(model, authorization: apiKey)
            case .unshare:
                let model = try decoder.decode(RuuviCloudApiShareRequest.self, from: requestBody)
                _ = try await api.unshare(model, authorization: apiKey)
            case .alert:
                let model = try decoder.decode(RuuviCloudApiPostAlertRequest.self, from: requestBody)
                _ = try await api.postAlert(model, authorization: apiKey)
            case .settings:
                let model = try decoder.decode(RuuviCloudApiPostSettingRequest.self, from: requestBody)
                _ = try await api.postSetting(model, authorization: apiKey)
            case .uploadImage:
                guard let imageData = request.additionalData else { return false }
                let model = try decoder.decode(RuuviCloudApiSensorImageUploadRequest.self, from: requestBody)
                _ = try await api.uploadImage(
                    model,
                    imageData: imageData,
                    authorization: apiKey,
                    uploadProgress: nil
                )
            default:
                return false
            }
            return true
        } catch let error as RuuviCloudApiError {
            throw RuuviCloudError.api(error)
        } catch {
            throw RuuviCloudError.api(.parsing(error))
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

    @discardableResult
    private func createQueuedRequest(
        from request: Codable,
        additionalData: Data? = nil,
        type: RuuviCloudQueuedRequestType,
        uniqueKey: String
    ) async throws -> Bool {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(request) else { return false }
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
        guard let pool else { return false }
        return try await pool.createQueuedRequest(request)
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
