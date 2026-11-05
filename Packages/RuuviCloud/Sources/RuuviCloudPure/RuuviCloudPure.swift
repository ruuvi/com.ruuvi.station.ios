#if SWIFT_PACKAGE
    import RuuviCloud
    import RuuviCloudApi
#endif
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
    @MainActor
    public func loadAlerts() async throws(RuuviCloudError) -> [RuuviCloudSensorAlerts] {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiGetAlertsRequest()
        do {
            let response = try await api.getAlerts(request, authorization: apiKey)
            return response.sensors ?? []
        } catch let error {
            throw .api(error)
        }
    }

    @discardableResult
    @MainActor
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
    ) async throws(RuuviCloudError) -> Void {
        notifyListener(state: .loading, macId: macId.mac)
        guard let apiKey = user.apiKey
        else {
            notifyListener(state: .failed, macId: macId.mac)
            throw .notAuthorized
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
        defer { self.notifyListener(state: .complete, macId: macId.mac) }
        do {
            _ = try await api.postAlert(request, authorization: apiKey)
            self.notifyListener(state: .success, macId: macId.mac)
        } catch let error {
            let uniqueKey = macId.value + "-" + type.rawValue + "-" + settingType.rawValue
            await self.createQueuedRequest(
                from: request,
                type: .alert,
                uniqueKey: uniqueKey
            )

            self.notifyListener(state: .failed, macId: macId.mac)
            throw .api(error)
        }
    }

    @discardableResult
    @MainActor
    public func set(temperatureUnit: TemperatureUnit) async throws(RuuviCloudError) -> TemperatureUnit {
        try await set(userSetting: .unitTemperature, value: temperatureUnit.ruuviCloudApiSettingString)
        return temperatureUnit
    }

    @discardableResult
    @MainActor
    public func set(temperatureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError)
        -> MeasurementAccuracyType
    {
        try await set(userSetting: .accuracyTemperature, value: temperatureAccuracy.value.ruuviCloudApiSettingString)
        return temperatureAccuracy
    }

    @discardableResult
    @MainActor
    public func set(humidityUnit: HumidityUnit) async throws(RuuviCloudError) -> HumidityUnit {
        try await set(userSetting: .unitHumidity, value: humidityUnit.ruuviCloudApiSettingString)
        return humidityUnit
    }

    @discardableResult
    @MainActor
    public func set(humidityAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType
    {
        try await set(userSetting: .accuracyHumidity, value: humidityAccuracy.value.ruuviCloudApiSettingString)
        return humidityAccuracy
    }

    @discardableResult
    @MainActor
    public func set(userSetting: RuuviCloudApiSetting, value: String) async throws(RuuviCloudError) -> String {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: userSetting,
            value: value,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            _ = try await api.postSetting(request, authorization: apiKey)
            return value
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: userSetting.rawValue
            )
            throw .api(error)
        }
    }

    @discardableResult
    @MainActor
    public func set(pressureUnit: UnitPressure) async throws(RuuviCloudError) -> UnitPressure {
        try await set(userSetting: .unitPressure, value: pressureUnit.ruuviCloudApiSettingString)
        return pressureUnit
    }

    @discardableResult
    @MainActor
    public func set(pressureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType
    {
        try await set(userSetting: .accuracyPressure, value: pressureAccuracy.value.ruuviCloudApiSettingString)
        return pressureAccuracy
    }

    @discardableResult
    @MainActor
    public func set(showAllData: Bool) async throws(RuuviCloudError) -> Bool {
        try await set(userSetting: .chartShowAllPoints, value: showAllData.chartBoolSettingString)
        return showAllData
    }

    @discardableResult
    @MainActor
    public func set(drawDots: Bool) async throws(RuuviCloudError) -> Bool {
        try await set(userSetting: .chartDrawDots, value: drawDots.chartBoolSettingString)
        return drawDots
    }

    @discardableResult
    @MainActor
    public func set(chartDuration: Int) async throws(RuuviCloudError) -> Int {
        try await set(userSetting: .chartViewPeriod, value: chartDuration.ruuviCloudApiSettingString)
        return chartDuration
    }

    @discardableResult
    @MainActor
    public func set(showMinMaxAvg: Bool) async throws(RuuviCloudError) -> Bool {
        try await set(userSetting: .chartShowMinMaxAverage, value: showMinMaxAvg.chartBoolSettingString)
        return showMinMaxAvg
    }

    @discardableResult
    @MainActor
    public func set(cloudMode: Bool) async throws(RuuviCloudError) -> Bool {
        try await set(userSetting: .cloudModeEnabled, value: cloudMode.chartBoolSettingString)
        return cloudMode
    }

    @discardableResult
    @MainActor
    public func set(dashboard: Bool) async throws(RuuviCloudError) -> Bool {
        try await set(userSetting: .dashboardEnabled, value: dashboard.chartBoolSettingString)
        return dashboard
    }

    @discardableResult
    @MainActor
    public func set(dashboardType: DashboardType) async throws(RuuviCloudError) -> DashboardType {
        try await set(userSetting: .dashboardType, value: dashboardType.rawValue)
        return dashboardType
    }

    @discardableResult
    @MainActor
    public func set(dashboardTapActionType: DashboardTapActionType) async throws(RuuviCloudError)
        -> DashboardTapActionType
    {
        try await set(userSetting: .dashboardTapActionType, value: dashboardTapActionType.rawValue)
        return dashboardTapActionType
    }

    @discardableResult
    @MainActor
    public func set(disableEmailAlert: Bool) async throws(RuuviCloudError) -> Bool {
        try await set(userSetting: .emailAlertDisabled, value: disableEmailAlert.chartBoolSettingString)
        return disableEmailAlert
    }

    @discardableResult
    @MainActor
    public func set(disablePushAlert: Bool) async throws(RuuviCloudError) -> Bool {
        try await set(userSetting: .pushAlertDisabled, value: disablePushAlert.chartBoolSettingString)
        return disablePushAlert
    }

    @discardableResult
    @MainActor
    public func getMarketingConsent() async throws(RuuviCloudError) -> RuuviCloudMarketingConsent {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let response: RuuviCloudMarketingConsent
        do { response = try await api.getMarketingConsent(authorization: apiKey) } catch { throw .api(error) }
        guard user.apiKey == apiKey else { throw .notAuthorized }
        return response
    }

    @discardableResult
    @MainActor
    public func set(marketingPreference: Bool) async throws(RuuviCloudError) -> RuuviCloudMarketingConsent {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiSetMarketingConsentRequest(
            consent: marketingPreference,
            silent: true,
            language: Bundle.main.preferredLocalizations.first ?? "en"
        )
        let response: RuuviCloudMarketingConsent
        do { response = try await api.setMarketingConsent(request, authorization: apiKey) } catch { throw .api(error) }
        guard user.apiKey == apiKey else { throw .notAuthorized }
        return response
    }

    @discardableResult
    @MainActor
    public func set(profileLanguageCode: String) async throws(RuuviCloudError) -> String {
        try await set(userSetting: .profileLanguageCode, value: profileLanguageCode)
        return profileLanguageCode
    }

    @discardableResult
    @MainActor
    public func set(dashboardSensorOrder: [String]) async throws(RuuviCloudError) -> [String] {
        guard let value = RuuviCloudApiHelper.jsonStringFromArray(dashboardSensorOrder) else {
            throw .api(.badParameters)
        }
        try await set(userSetting: .dashboardSensorOrder, value: value)
        return dashboardSensorOrder
    }

    @discardableResult
    @MainActor
    public func getCloudSettings() async throws(RuuviCloudError) -> RuuviCloudSettings? {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiGetSettingsRequest()
        do {
            let response = try await api.getSettings(request, authorization: apiKey)
            return response.settings
        } catch let error {
            throw .api(error)
        }
    }

    @discardableResult
    @MainActor
    public func resetImage(
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> Void {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiSensorImageUploadRequest(
            sensor: macId.value,
            action: .reset
        )
        do {
            _ = try await api.resetImage(request, authorization: apiKey)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .uploadImage,
                uniqueKey: macId.value + "-uploadImage"
            )
            throw .api(error)
        }
    }

    @MainActor
    public func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> URL {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
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
        } catch let error {
            let uniqueKey = macId.value + "-uploadImage"
            await self.createQueuedRequest(
                from: requestModel,
                additionalData: imageData,
                type: .uploadImage,
                uniqueKey: uniqueKey
            )
            throw .api(error)
        }
    }

    @discardableResult
    @MainActor
    public func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }

        guard types.count == values.count else {
            throw .api(.badParameters)
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
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .sensorSettings,
                uniqueKey: sensor.id + "-sensor-settings"
            )
            throw .api(error)
        }
    }

    @MainActor
    public func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
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
        } catch let error {
            var keySuffix: String = ""
            if temperatureOffset != nil {
                keySuffix = "-temperatureOffset"
            } else if humidityOffset != nil {
                keySuffix = "-humidityOffset"
            } else if pressureOffset != nil {
                keySuffix = "-pressureOffset"
            }
            let uniqueKey = sensor.id + keySuffix

            await self.createQueuedRequest(
                from: request,
                type: .sensor,
                uniqueKey: uniqueKey
            )

            throw .api(error)
        }
    }

    @MainActor
    public func update(
        name: String,
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        notifyListener(state: .loading, macId: sensor.id)
        guard let apiKey = user.apiKey
        else {
            notifyListener(state: .failed, macId: sensor.id)
            throw .notAuthorized
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
            _ = try await api.update(request, authorization: apiKey)
            let updated = sensor.with(name: name).any
            self.notifyListener(state: .success, macId: sensor.id)
            return updated
        } catch let error {
            let uniqueKey = sensor.id + "-name"
            await self.createQueuedRequest(
                from: request,
                type: .sensor,
                uniqueKey: uniqueKey
            )
            self.notifyListener(state: .failed, macId: sensor.id)
            throw .api(error)
        }
    }

    @MainActor
    public func loadShared(for sensor: RuuviTagSensor) async throws(RuuviCloudError) -> Set<AnyShareableSensor> {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiGetSensorsRequest(sensor: sensor.id)
        do {
            let response = try await api.sensors(request, authorization: apiKey)
            let arrayOfAny = response.sensors?.map(\.shareableSensor.any)
            let setOfAny = Set<AnyShareableSensor>(arrayOfAny ?? [])
            return setOfAny
        } catch let error {
            throw .api(error)
        }
    }

    @discardableResult
    @MainActor
    public func checkOwner(macId: MACIdentifier) async throws(RuuviCloudError) -> (String?, String?) {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiGetSensorsRequest(sensor: macId.mac)
        do {
            let response = try await api.owner(request, authorization: apiKey)
            return (response.email, response.sensor)
        } catch let error {
            throw .api(error)
        }
    }

    @MainActor
    // swiftlint:disable:next function_parameter_count function_body_length
    public func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) async throws(RuuviCloudError) -> [RuuviCloudSensorDense] {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
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
                        sharedToPending: sensor.sharedToPending ?? [],
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
        } catch let error {
            throw .api(error)
        }
    }

    @MainActor
    public func share(macId: MACIdentifier, with email: String) async throws(RuuviCloudError) -> ShareSensorResponse {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
        do {
            let response = try await api.share(request, authorization: apiKey)
            let result = ShareSensorResponse(
                macId: response.sensor?.mac,
                invited: response.invited
            )
            return result
        } catch let error {
            throw .api(error)
        }
    }

    @MainActor
    public func unshare(macId: MACIdentifier, with email: String?) async throws(RuuviCloudError) -> MACIdentifier {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
        do {
            _ = try await api.unshare(request, authorization: apiKey)
            return macId
        } catch let error {
            // A nil recipient removes the current user's share and also needs an offline retry.
            let uniqueKey = macId.mac + "-unshare-" + (email ?? "$self")
            await self.createQueuedRequest(
                from: request,
                type: .unshare,
                uniqueKey: uniqueKey
            )
            throw .api(error)
        }
    }

    @MainActor
    public func claim(
        name: String,
        macId: MACIdentifier
    ) async throws(RuuviCloudError) -> MACIdentifier? {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiClaimRequest(name: name, sensor: macId.value)
        do {
            let response = try await api.claim(request, authorization: apiKey)
            return response.sensor?.mac
        } catch let error {
            throw .api(error)
        }
    }

    @discardableResult
    @MainActor
    public func contest(
        macId: MACIdentifier,
        secret: String
    ) async throws(RuuviCloudError) -> MACIdentifier? {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiContestRequest(sensor: macId.value, secret: secret)
        do {
            let response = try await api.contest(request, authorization: apiKey)
            return response.sensor?.mac
        } catch let error {
            throw .api(error)
        }
    }

    @MainActor
    public func unclaim(
        macId: MACIdentifier,
        removeCloudHistory: Bool
    ) async throws(RuuviCloudError) -> MACIdentifier {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiUnclaimRequest(
            sensor: macId.value,
            deleteData: removeCloudHistory
        )
        do {
            _ = try await api.unclaim(request, authorization: apiKey)
            return macId
        } catch let error {
            let uniqueKey = macId.mac + "-unclaim"
            await self.createQueuedRequest(
                from: request,
                type: .unclaim,
                uniqueKey: uniqueKey
            )
            throw .api(error)
        }
    }

    @MainActor
    public func requestCode(email: String) async throws(RuuviCloudError) -> String? {
        let request = RuuviCloudApiRegisterRequest(email: email)
        do {
            let response = try await api.register(request)
            return response.email
        } catch let error {
            throw .api(error)
        }
    }

    @MainActor
    public func validateCode(code: String) async throws(RuuviCloudError) -> ValidateCodeResponse {
        let response: RuuviCloudApiVerifyResponse
        do { response = try await api.verify(RuuviCloudApiVerifyRequest(token: code)) } catch { throw .api(error) }
        guard let email = response.email, let accessToken = response.accessToken else {
            throw .api(.api(.erInternal))
        }
        return ValidateCodeResponse(email: email, apiKey: accessToken)
    }

    @MainActor
    public func deleteAccount(email: String) async throws(RuuviCloudError) -> Bool {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudApiAccountDeleteRequest(email: email)
        do {
            let response = try await api.deleteAccount(
                request,
                authorization: apiKey
            )
            return response.email == email
        } catch let error {
            throw .api(error)
        }
    }

    @MainActor
    public func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws(RuuviCloudError) -> Int {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
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
        } catch let error {
            throw .api(error)
        }
    }

    @MainActor
    public func unregisterPNToken(
        token: String?,
        tokenId: Int?
    ) async throws(RuuviCloudError) -> Bool {
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
        } catch let error {
            throw .api(error)
        }
    }

    @MainActor
    public func listPNTokens() async throws(RuuviCloudError) -> [RuuviCloudPNToken] {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        let request = RuuviCloudPNTokenListRequest()
        do {
            let response = try await api.listPNTokens(
                request,
                authorization: apiKey
            )
            let tokens = response.anyTokens
            return tokens
        } catch let error {
            throw .api(error)
        }
    }

    @MainActor
    public func loadSensors() async throws(RuuviCloudError) -> [AnyCloudSensor] {
        guard let apiKey = user.apiKey
        else {
            throw .notAuthorized
        }
        do {
            let response = try await api.user(authorization: apiKey)
            let email = response.email
            let sensors = response.sensors.map { $0.with(email: email).any }
            return sensors
        } catch let error {
            throw .api(error)
        }
    }

    @MainActor
    public func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws(RuuviCloudError) -> [AnyRuuviTagSensorRecord] {
        guard let apiKey = user.apiKey else { throw .notAuthorized }
        var cursor = since
        var records = [AnyRuuviTagSensorRecord]()
        var seen = Set<String>()
        while true {
            if Task.isCancelled { throw .api(.networking(CancellationError())) }
            let request = RuuviCloudApiGetSensorRequest(
                sensor: macId.value,
                until: until?.timeIntervalSince1970,
                since: cursor.timeIntervalSince1970,
                limit: 5000,
                sort: .asc
            )
            let response: RuuviCloudApiGetSensorResponse
            do {
                response = try await api.getSensorData(request, authorization: apiKey)
            } catch { throw .api(error) }
            let fetched = decodeSensorRecords(macId: macId, response: response)
            records.append(contentsOf: fetched.filter { seen.insert($0.id).inserted })
            // Pagination belongs to the raw API page. Unsupported or malformed payloads must not
            // hide later history, and a repeated page must not cause an endless request loop.
            guard let measurements = response.measurements,
                measurements.count == 5000,
                let timestamp = measurements.compactMap(\.timestamp).filter(\.isFinite).max(),
                timestamp > cursor.timeIntervalSince1970
            else { return records }
            let next = Date(timeIntervalSince1970: timestamp)
            if let until, next >= until { return records }
            cursor = next
        }
    }

    @MainActor
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    public func executeQueuedRequest(from request: RuuviCloudQueuedRequest)
        async throws(RuuviCloudError) -> Bool
    {
        guard let apiKey = user.apiKey else { throw .notAuthorized }
        guard let type = request.type, let data = request.requestBodyData else {
            throw .api(.badParameters)
        }
        let decoder = JSONDecoder()
        do {
            switch type {
            case .sensor:
                let model = try decoder.decode(RuuviCloudApiSensorUpdateRequest.self, from: data)
                _ = try await api.update(model, authorization: apiKey)
            case .unclaim:
                let model = try decoder.decode(RuuviCloudApiUnclaimRequest.self, from: data)
                _ = try await api.unclaim(model, authorization: apiKey)
            case .unshare:
                let model = try decoder.decode(RuuviCloudApiShareRequest.self, from: data)
                _ = try await api.unshare(model, authorization: apiKey)
            case .alert:
                let model = try decoder.decode(RuuviCloudApiPostAlertRequest.self, from: data)
                _ = try await api.postAlert(model, authorization: apiKey)
            case .settings:
                let model = try decoder.decode(RuuviCloudApiPostSettingRequest.self, from: data)
                _ = try await api.postSetting(model, authorization: apiKey)
            case .sensorSettings:
                let model = try decoder.decode(RuuviCloudApiPostSensorSettingsRequest.self, from: data)
                _ = try await api.postSensorSettings(model, authorization: apiKey)
            case .uploadImage:
                let model = try decoder.decode(RuuviCloudApiSensorImageUploadRequest.self, from: data)
                if model.action == .reset {
                    _ = try await api.resetImage(model, authorization: apiKey)
                } else if let image = request.additionalData {
                    _ = try await api.uploadImage(model, imageData: image, authorization: apiKey, uploadProgress: nil)
                } else {
                    throw RuuviCloudApiError.badParameters
                }
            case .none:
                throw RuuviCloudApiError.badParameters
            }
            return true
        } catch let error as RuuviCloudApiError {
            throw .api(error)
        } catch {
            throw .api(.parsing(error))
        }
    }

    static func isValidNetworkPayload(_ payload: String) -> Bool {
        // BTKit's hex/advertisement parser assumes complete pairs and AD structures.
        // Validate untrusted server data before it reaches those indexing operations.
        let hex = Array(payload.utf8)
        guard hex.count.isMultiple(of: 2), hex.count > 36 else { return false }
        func nibble(_ byte: UInt8) -> UInt8? {
            switch byte {
            case 48...57: return byte - 48
            case 65...70: return byte - 55
            case 97...102: return byte - 87
            default: return nil
            }
        }
        var bytes: [UInt8] = []
        for index in stride(from: 0, to: hex.count, by: 2) {
            guard let high = nibble(hex[index]), let low = nibble(hex[index + 1]) else { return false }
            bytes.append(high * 16 + low)
        }
        var index = 0
        while index < bytes.count {
            let length = Int(bytes[index])
            index += 1
            guard length <= bytes.count - index else { return false }
            index += length
        }
        return true
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
            guard let timestamp = measurement.timestamp, timestamp.isFinite,
                let rssi = measurement.rssi,
                let data = measurement.data, Self.isValidNetworkPayload(data),
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
                date: Date(timeIntervalSince1970: timestamp),
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
            let data = record.data, Self.isValidNetworkPayload(data),
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

    @MainActor
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
