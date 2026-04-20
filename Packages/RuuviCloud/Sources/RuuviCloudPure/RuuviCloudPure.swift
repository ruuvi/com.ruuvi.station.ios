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

    @discardableResult
    public func loadAlerts() async throws -> [RuuviCloudSensorAlerts] {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let response = try await self.api.getAlerts(
                RuuviCloudApiGetAlertsRequest(),
                authorization: apiKey
            )
            return response.sensors ?? []
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
        let uniqueKey = macId.value + "-" + type.rawValue + "-" + settingType.rawValue
        defer { self.notifyListener(state: .complete, macId: macId.mac) }
        do {
            _ = try await self.api.postAlert(request, authorization: apiKey)
            self.notifyListener(state: .success, macId: macId.mac)
        } catch let error as RuuviCloudApiError {
            self.createQueuedRequest(
                from: request,
                type: .alert,
                uniqueKey: uniqueKey
            )
            self.notifyListener(state: .failed, macId: macId.mac)
            throw RuuviCloudError.api(error)
        } catch let error as RuuviCloudError {
            self.notifyListener(state: .failed, macId: macId.mac)
            throw error
        } catch {
            self.notifyListener(state: .failed, macId: macId.mac)
            throw RuuviCloudError.api(.networking(error))
        }
    }

    @discardableResult
    public func set(temperatureUnit: TemperatureUnit) async throws -> TemperatureUnit {
        try await setSetting(
            temperatureUnit,
            name: .unitTemperature,
            value: temperatureUnit.ruuviCloudApiSettingString
        )
    }

    @discardableResult
    public func set(temperatureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        try await setSetting(
            temperatureAccuracy,
            name: .accuracyTemperature,
            value: temperatureAccuracy.value.ruuviCloudApiSettingString
        )
    }

    @discardableResult
    public func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit {
        try await setSetting(
            humidityUnit,
            name: .unitHumidity,
            value: humidityUnit.ruuviCloudApiSettingString
        )
    }

    @discardableResult
    public func set(humidityAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        try await setSetting(
            humidityAccuracy,
            name: .accuracyHumidity,
            value: humidityAccuracy.value.ruuviCloudApiSettingString
        )
    }

    @discardableResult
    public func set(pressureUnit: UnitPressure) async throws -> UnitPressure {
        try await setSetting(
            pressureUnit,
            name: .unitPressure,
            value: pressureUnit.ruuviCloudApiSettingString
        )
    }

    @discardableResult
    public func set(pressureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        try await setSetting(
            pressureAccuracy,
            name: .accuracyPressure,
            value: pressureAccuracy.value.ruuviCloudApiSettingString
        )
    }

    @discardableResult
    public func set(showAllData: Bool) async throws -> Bool {
        try await setSetting(
            showAllData,
            name: .chartShowAllPoints,
            value: showAllData.chartBoolSettingString
        )
    }

    @discardableResult
    public func set(drawDots: Bool) async throws -> Bool {
        try await setSetting(
            drawDots,
            name: .chartDrawDots,
            value: drawDots.chartBoolSettingString
        )
    }

    @discardableResult
    public func set(chartDuration: Int) async throws -> Int {
        try await setSetting(
            chartDuration,
            name: .chartViewPeriod,
            value: chartDuration.ruuviCloudApiSettingString
        )
    }

    @discardableResult
    public func set(showMinMaxAvg: Bool) async throws -> Bool {
        try await setSetting(
            showMinMaxAvg,
            name: .chartShowMinMaxAverage,
            value: showMinMaxAvg.chartBoolSettingString
        )
    }

    @discardableResult
    public func set(cloudMode: Bool) async throws -> Bool {
        try await setSetting(
            cloudMode,
            name: .cloudModeEnabled,
            value: cloudMode.chartBoolSettingString
        )
    }

    @discardableResult
    public func set(dashboard: Bool) async throws -> Bool {
        try await setSetting(
            dashboard,
            name: .dashboardEnabled,
            value: dashboard.chartBoolSettingString
        )
    }

    @discardableResult
    public func set(dashboardType: DashboardType) async throws -> DashboardType {
        try await setSetting(
            dashboardType,
            name: .dashboardType,
            value: dashboardType.rawValue
        )
    }

    @discardableResult
    public func set(dashboardTapActionType: DashboardTapActionType) async throws
    -> DashboardTapActionType {
        try await setSetting(
            dashboardTapActionType,
            name: .dashboardTapActionType,
            value: dashboardTapActionType.rawValue
        )
    }

    @discardableResult
    public func set(disableEmailAlert: Bool) async throws -> Bool {
        try await setSetting(
            disableEmailAlert,
            name: .emailAlertDisabled,
            value: disableEmailAlert.chartBoolSettingString
        )
    }

    @discardableResult
    public func set(disablePushAlert: Bool) async throws -> Bool {
        try await setSetting(
            disablePushAlert,
            name: .pushAlertDisabled,
            value: disablePushAlert.chartBoolSettingString
        )
    }

    @discardableResult
    public func set(marketingPreference: Bool) async throws -> Bool {
        try await setSetting(
            marketingPreference,
            name: .marketingPreference,
            value: marketingPreference.chartBoolSettingString
        )
    }

    @discardableResult
    public func set(profileLanguageCode: String) async throws -> String {
        try await setSetting(
            profileLanguageCode,
            name: .profileLanguageCode,
            value: profileLanguageCode
        )
    }

    @discardableResult
    public func set(dashboardSensorOrder: [String]) async throws -> [String] {
        try await setSetting(
            dashboardSensorOrder,
            name: .dashboardSensorOrder,
            value: RuuviCloudApiHelper.jsonStringFromArray(dashboardSensorOrder)
        )
    }

    @discardableResult
    public func getCloudSettings() async throws -> RuuviCloudSettings? {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let response = try await self.api.getSettings(
                RuuviCloudApiGetSettingsRequest(),
                authorization: apiKey
            )
            return response.settings
        }
    }

    @discardableResult
    public func resetImage(
        for macId: MACIdentifier
    ) async throws {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let request = RuuviCloudApiSensorImageUploadRequest(
                sensor: macId.value,
                action: .reset
            )
            _ = try await self.api.resetImage(request, authorization: apiKey)
        }
    }

    public func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws -> URL {
        let requestModel = RuuviCloudApiSensorImageUploadRequest(
            sensor: macId.value,
            action: .upload,
            mimeType: mimeType
        )
        return try await queueingOperation(
            request: requestModel,
            additionalData: imageData,
            type: .uploadImage,
            uniqueKey: macId.value + "-uploadImage"
        ) { apiKey, request in
            let response = try await self.api.uploadImage(
                request,
                imageData: imageData,
                authorization: apiKey,
                uploadProgress: { percentage in
                    progress?(macId, percentage)
                }
            )
            return response.uploadURL
        }
    }

    @discardableResult
    public func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws -> AnyRuuviTagSensor {
        guard types.count == values.count else {
            throw RuuviCloudError.api(.badParameters)
        }

        let request = RuuviCloudApiPostSensorSettingsRequest(
            sensor: sensor.id,
            type: types,
            value: values,
            timestamp: timestamp ?? Int(Date().timeIntervalSince1970)
        )

        return try await queueingOperation(
            request: request,
            type: .sensorSettings,
            uniqueKey: sensor.id + "-sensor-settings"
        ) { apiKey, request in
            _ = try await self.api.postSensorSettings(request, authorization: apiKey)
            return sensor.any
        }
    }

    public func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor {
        let request = RuuviCloudApiSensorUpdateRequest(
            sensor: sensor.id,
            name: sensor.name,
            offsetTemperature: temperatureOffset,
            offsetHumidity: humidityOffset,
            offsetPressure: pressureOffset,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        let uniqueKey: String
        if temperatureOffset != nil {
            uniqueKey = sensor.id + "-temperatureOffset"
        } else if humidityOffset != nil {
            uniqueKey = sensor.id + "-humidityOffset"
        } else if pressureOffset != nil {
            uniqueKey = sensor.id + "-pressureOffset"
        } else {
            uniqueKey = sensor.id
        }
        return try await queueingOperation(
            request: request,
            type: .sensor,
            uniqueKey: uniqueKey
        ) { apiKey, request in
            _ = try await self.api.update(request, authorization: apiKey)
            return sensor.any
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
        defer { self.notifyListener(state: .complete, macId: sensor.id) }
        do {
            _ = try await self.api.update(request, authorization: apiKey)
            self.notifyListener(state: .success, macId: sensor.id)
            return sensor.with(name: name).any
        } catch let error as RuuviCloudApiError {
            self.createQueuedRequest(
                from: request,
                type: .sensor,
                uniqueKey: sensor.id + "-name"
            )
            self.notifyListener(state: .failed, macId: sensor.id)
            throw RuuviCloudError.api(error)
        } catch let error as RuuviCloudError {
            self.notifyListener(state: .failed, macId: sensor.id)
            throw error
        } catch {
            self.notifyListener(state: .failed, macId: sensor.id)
            throw RuuviCloudError.api(.networking(error))
        }
    }

    public func loadShared(for sensor: RuuviTagSensor) async throws -> Set<AnyShareableSensor> {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let request = RuuviCloudApiGetSensorsRequest(sensor: sensor.id)
            let response = try await self.api.sensors(request, authorization: apiKey)
            let arrayOfAny = response.sensors?.map(\.shareableSensor.any)
            return Set<AnyShareableSensor>(arrayOfAny ?? [])
        }
    }

    @discardableResult
    public func checkOwner(macId: MACIdentifier) async throws -> (String?, String?) {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let request = RuuviCloudApiGetSensorsRequest(sensor: macId.mac)
            let response = try await self.api.owner(request, authorization: apiKey)
            return (response.email, response.sensor)
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
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let request = RuuviCloudApiGetSensorsDenseRequest(
                sensor: sensor?.id,
                measurements: measurements,
                sharedToMe: sharedToMe,
                sharedToOthers: sharedToOthers,
                alerts: alerts,
                settings: settings
            )
            let response = try await self.api.sensorsDense(request, authorization: apiKey)
            let arrayOfAny = response.sensors?.compactMap { sensor in
                let ownerEmail = sensor.owner.lowercased()
                let userEmail = self.user.email?.lowercased()
                let isOwner = ownerEmail == userEmail
                return RuuviCloudSensorDense(
                    sensor: CloudSensorStruct(
                        id: sensor.sensor,
                        serviceUUID: nil,
                        name: sensor.name,
                        isClaimed: true,
                        isOwner: isOwner,
                        owner: ownerEmail,
                        ownersPlan: sensor.subscription?.subscriptionName,
                        picture: URL(string: sensor.picture),
                        offsetTemperature: sensor.offsetTemperature,
                        offsetHumidity: sensor.offsetHumidity,
                        offsetPressure: sensor.offsetPressure,
                        isCloudSensor: true,
                        canShare: sensor.canShare,
                        sharedTo: sensor.sharedTo ?? [],
                        maxHistoryDays: sensor.subscription?.maxHistoryDays,
                        lastUpdated: sensor.lastUpdatedDate
                    ),
                    record: self.decodeSensorRecord(
                        macId: sensor.sensor.mac,
                        record: sensor.lastMeasurement
                    ),
                    alerts: sensor.alerts,
                    subscription: sensor.subscription,
                    settings: sensor.settings.map {
                        RuuviCloudSensorSettings(
                            displayOrderCodes: $0.displayOrderCodes,
                            defaultDisplayOrder: $0.defaultDisplayOrder,
                            displayOrderLastUpdated: $0.displayOrderLastUpdatedDate,
                            defaultDisplayOrderLastUpdated: $0.defaultDisplayOrderLastUpdatedDate,
                            description: $0.description,
                            descriptionLastUpdated: $0.descriptionLastUpdatedDate
                        )
                    }
                )
            }
            return arrayOfAny ?? []
        }
    }

    public func share(macId: MACIdentifier, with email: String) async throws -> ShareSensorResponse {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
            let response = try await self.api.share(request, authorization: apiKey)
            return ShareSensorResponse(
                macId: response.sensor?.mac,
                invited: response.invited
            )
        }
    }

    public func unshare(macId: MACIdentifier, with email: String?) async throws -> MACIdentifier {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
            do {
                _ = try await self.api.unshare(request, authorization: apiKey)
                return macId
            } catch let error as RuuviCloudApiError {
                if let email {
                    self.createQueuedRequest(
                        from: request,
                        type: .unshare,
                        uniqueKey: macId.mac + "-unshare-" + email
                    )
                }
                throw error
            }
        }
    }

    public func claim(
        name: String,
        macId: MACIdentifier
    ) async throws -> MACIdentifier? {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let request = RuuviCloudApiClaimRequest(name: name, sensor: macId.value)
            let response = try await self.api.claim(request, authorization: apiKey)
            return response.sensor?.mac
        }
    }

    @discardableResult
    public func contest(
        macId: MACIdentifier,
        secret: String
    ) async throws -> MACIdentifier? {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let request = RuuviCloudApiContestRequest(sensor: macId.value, secret: secret)
            let response = try await self.api.contest(request, authorization: apiKey)
            return response.sensor?.mac
        }
    }

    public func unclaim(
        macId: MACIdentifier,
        removeCloudHistory: Bool
    ) async throws -> MACIdentifier {
        let request = RuuviCloudApiUnclaimRequest(
            sensor: macId.value,
            deleteData: removeCloudHistory
        )
        return try await queueingOperation(
            request: request,
            type: .unclaim,
            uniqueKey: macId.mac + "-unclaim"
        ) { apiKey, request in
            _ = try await self.api.unclaim(request, authorization: apiKey)
            return macId
        }
    }

    public func requestCode(email: String) async throws -> String? {
        try await cloudOperation {
            let request = RuuviCloudApiRegisterRequest(email: email)
            let response = try await self.api.register(request)
            return response.email
        }
    }

    public func validateCode(code: String) async throws -> ValidateCodeResponse {
        try await cloudOperation {
            let request = RuuviCloudApiVerifyRequest(token: code)
            let response = try await self.api.verify(request)
            guard let email = response.email,
                  let accessToken = response.accessToken
            else {
                throw RuuviCloudApiError.api(.erInternal)
            }
            return ValidateCodeResponse(
                email: email,
                apiKey: accessToken
            )
        }
    }

    public func deleteAccount(email: String) async throws -> Bool {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let request = RuuviCloudApiAccountDeleteRequest(email: email)
            let response = try await self.api.deleteAccount(
                request,
                authorization: apiKey
            )
            return response.email == email
        }
    }

    public func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws -> Int {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let request = RuuviCloudPNTokenRegisterRequest(
                token: token,
                type: type,
                name: name,
                data: data,
                params: params
            )
            let response = try await self.api.registerPNToken(
                request,
                authorization: apiKey
            )
            return response.id
        }
    }

    public func unregisterPNToken(
        token: String?,
        tokenId: Int?
    ) async throws -> Bool {
        try await cloudOperation {
            let request = RuuviCloudPNTokenUnregisterRequest(
                token: token,
                id: tokenId
            )
            _ = try await self.api.unregisterPNToken(
                request,
                authorization: self.user.apiKey
            )
            return true
        }
    }

    public func listPNTokens() async throws -> [RuuviCloudPNToken] {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let response = try await self.api.listPNTokens(
                RuuviCloudPNTokenListRequest(),
                authorization: apiKey
            )
            return response.anyTokens
        }
    }

    public func loadSensors() async throws -> [AnyCloudSensor] {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            let response = try await self.api.user(authorization: apiKey)
            let email = response.email
            return response.sensors.map { $0.with(email: email).any }
        }
    }

    @discardableResult
    public func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws -> [AnyRuuviTagSensorRecord] {
        try await cloudOperation {
            try await self.loadRecordsByChunkAsync(
                macId: macId,
                since: since,
                until: until,
                records: [],
                chunkSize: 5000 // TODO: @rinat replace with setting
            )
        }
    }

    public func executeQueuedRequest(from request: RuuviCloudQueuedRequest)
    async throws -> Bool {
        try await cloudOperation {
            try await self.executeQueuedRequestAsync(from: request)
        }
    }

    private func authorizedApiKey() throws -> String {
        guard let apiKey = user.apiKey else {
            throw RuuviCloudError.notAuthorized
        }
        return apiKey
    }

    private func cloudOperation<Value>(
        _ task: () async throws -> Value
    ) async throws -> Value {
        do {
            return try await task()
        } catch let error as RuuviCloudError {
            throw error
        } catch let error as RuuviCloudApiError {
            throw RuuviCloudError.api(error)
        } catch {
            throw RuuviCloudError.api(.networking(error))
        }
    }

    private func setSetting<Value>(
        _ result: Value,
        name: RuuviCloudApiSetting,
        value: String?
    ) async throws -> Value {
        let request = RuuviCloudApiPostSettingRequest(
            name: name,
            value: value,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        return try await queueingOperation(
            request: request,
            type: .settings,
            uniqueKey: name.rawValue
        ) { apiKey, request in
            _ = try await self.api.postSetting(request, authorization: apiKey)
            return result
        }
    }

    private func queueingOperation<Request: Codable, Value>(
        request: Request,
        additionalData: Data? = nil,
        type: RuuviCloudQueuedRequestType,
        uniqueKey: String,
        operation: @escaping (String, Request) async throws -> Value
    ) async throws -> Value {
        try await cloudOperation {
            let apiKey = try self.authorizedApiKey()
            do {
                return try await operation(apiKey, request)
            } catch let error as RuuviCloudApiError {
                self.createQueuedRequest(
                    from: request,
                    additionalData: additionalData,
                    type: type,
                    uniqueKey: uniqueKey
                )
                throw error
            }
        }
    }

    private func loadRecordsByChunkAsync(
        macId: MACIdentifier,
        since: Date,
        until: Date?,
        records: [AnyRuuviTagSensorRecord],
        chunkSize: Int
    ) async throws -> [AnyRuuviTagSensorRecord] {
        let apiKey = try authorizedApiKey()
        let request = RuuviCloudApiGetSensorRequest(
            sensor: macId.value,
            until: until?.timeIntervalSince1970,
            since: since.timeIntervalSince1970,
            limit: chunkSize,
            sort: .asc
        )
        let response = try await api.getSensorData(request, authorization: apiKey)
        let fetchedRecords = decodeSensorRecords(macId: macId, response: response)
        let allRecords = records + fetchedRecords
        // Offset is to check whether we have recent minute data. (Current time + 1 min)
        let offset = Date().addingTimeInterval(1 * 60)
        if let lastRecord = fetchedRecords.last,
           !records.contains(lastRecord) {
            let loadable = (until != nil && lastRecord.date < until!) || lastRecord.date > offset
            if loadable {
                return try await loadRecordsByChunkAsync(
                    macId: macId,
                    since: lastRecord.date,
                    until: until,
                    records: allRecords,
                    chunkSize: chunkSize
                )
            }
        }
        return allRecords
    }

    // swiftlint:disable:next function_body_length
    private func executeQueuedRequestAsync(
        from queuedRequest: RuuviCloudQueuedRequest
    ) async throws -> Bool {
        let apiKey = try authorizedApiKey()
        guard let type = queuedRequest.type,
              let requestBody = queuedRequest.requestBodyData
        else {
            throw RuuviCloudApiError.badParameters
        }

        switch type {
        case .sensor:
            let request = try decodeQueuedRequest(
                RuuviCloudApiSensorUpdateRequest.self,
                from: requestBody
            )
            _ = try await api.update(request, authorization: apiKey)
            return true
        case .unclaim:
            let request = try decodeQueuedRequest(
                RuuviCloudApiUnclaimRequest.self,
                from: requestBody
            )
            _ = try await api.unclaim(request, authorization: apiKey)
            return true
        case .unshare:
            let request = try decodeQueuedRequest(
                RuuviCloudApiShareRequest.self,
                from: requestBody
            )
            _ = try await api.unshare(request, authorization: apiKey)
            return true
        case .alert:
            let request = try decodeQueuedRequest(
                RuuviCloudApiPostAlertRequest.self,
                from: requestBody
            )
            _ = try await api.postAlert(request, authorization: apiKey)
            return true
        case .settings:
            let request = try decodeQueuedRequest(
                RuuviCloudApiPostSettingRequest.self,
                from: requestBody
            )
            _ = try await api.postSetting(request, authorization: apiKey)
            return true
        case .sensorSettings:
            let request = try decodeQueuedRequest(
                RuuviCloudApiPostSensorSettingsRequest.self,
                from: requestBody
            )
            _ = try await api.postSensorSettings(request, authorization: apiKey)
            return true
        case .uploadImage:
            guard let imageData = queuedRequest.additionalData else {
                throw RuuviCloudApiError.badParameters
            }
            let request = try decodeQueuedRequest(
                RuuviCloudApiSensorImageUploadRequest.self,
                from: requestBody
            )
            _ = try await api.uploadImage(
                request,
                imageData: imageData,
                authorization: apiKey,
                uploadProgress: nil
            )
            return true
        case .none:
            throw RuuviCloudApiError.badParameters
        }
    }

    private func decodeQueuedRequest<Request: Decodable>(
        _ type: Request.Type,
        from data: Data
    ) throws -> Request {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw RuuviCloudApiError.parsing(error)
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
                  isHexEncodedPayload(data),
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
              isHexEncodedPayload(data),
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

    private func isHexEncodedPayload(_ payload: String) -> Bool {
        guard payload.count.isMultiple(of: 2) else {
            return false
        }
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return payload.unicodeScalars.allSatisfy {
            hexCharacters.contains($0)
        }
    }

    private func createQueuedRequest(
        from request: Codable,
        additionalData: Data? = nil,
        type: RuuviCloudQueuedRequestType,
        uniqueKey: String
    ) {
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
        Task {
            _ = try? await pool?.createQueuedRequest(request)
        }
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
