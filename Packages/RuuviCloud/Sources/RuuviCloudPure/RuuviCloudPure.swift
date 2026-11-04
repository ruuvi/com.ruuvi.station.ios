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
        var outcome: Result<[RuuviCloudSensorAlerts], RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiGetAlertsRequest()
        do {
            let response = try await api.getAlerts(request, authorization: apiKey)
            outcome = .success(response.sensors ?? [])
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
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
        var outcome: Result<Void, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            notifyListener(state: .failed, macId: macId.mac)
            return try outcome.get()
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
            let _ = try await api.postAlert(request, authorization: apiKey)
            outcome = .success(())
            self.notifyListener(state: .success, macId: macId.mac)
        } catch let error {
            let uniqueKey = macId.value + "-" + type.rawValue + "-" + settingType.rawValue
            await self.createQueuedRequest(
                from: request,
                type: .alert,
                uniqueKey: uniqueKey
            )

            outcome = .failure(.api(error))
            self.notifyListener(state: .failed, macId: macId.mac)
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(temperatureUnit: TemperatureUnit) async throws(RuuviCloudError) -> TemperatureUnit {
        var outcome: Result<TemperatureUnit, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .unitTemperature,
            value: temperatureUnit.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(temperatureUnit)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.unitTemperature.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(temperatureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError)
        -> MeasurementAccuracyType
    {
        var outcome: Result<MeasurementAccuracyType, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .accuracyTemperature,
            value: temperatureAccuracy.value.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(temperatureAccuracy)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.accuracyTemperature.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(humidityUnit: HumidityUnit) async throws(RuuviCloudError) -> HumidityUnit {
        var outcome: Result<HumidityUnit, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .unitHumidity,
            value: humidityUnit.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(humidityUnit)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.unitHumidity.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(humidityAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType
    {
        var outcome: Result<MeasurementAccuracyType, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .accuracyHumidity,
            value: humidityAccuracy.value.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(humidityAccuracy)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.accuracyHumidity.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(userSetting: RuuviCloudApiSetting, value: String) async throws(RuuviCloudError) -> String {
        var outcome: Result<String, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: userSetting,
            value: value,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(value)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: userSetting.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(pressureUnit: UnitPressure) async throws(RuuviCloudError) -> UnitPressure {
        var outcome: Result<UnitPressure, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .unitPressure,
            value: pressureUnit.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(pressureUnit)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.unitPressure.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(pressureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType
    {
        var outcome: Result<MeasurementAccuracyType, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .accuracyPressure,
            value: pressureAccuracy.value.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(pressureAccuracy)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.accuracyPressure.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(showAllData: Bool) async throws(RuuviCloudError) -> Bool {
        var outcome: Result<Bool, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartShowAllPoints,
            value: showAllData.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(showAllData)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.chartShowAllPoints.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(drawDots: Bool) async throws(RuuviCloudError) -> Bool {
        var outcome: Result<Bool, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartDrawDots,
            value: drawDots.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(drawDots)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.chartDrawDots.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(chartDuration: Int) async throws(RuuviCloudError) -> Int {
        var outcome: Result<Int, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartViewPeriod,
            value: chartDuration.ruuviCloudApiSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(chartDuration)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.chartViewPeriod.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(showMinMaxAvg: Bool) async throws(RuuviCloudError) -> Bool {
        var outcome: Result<Bool, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .chartShowMinMaxAverage,
            value: showMinMaxAvg.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(showMinMaxAvg)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.chartShowMinMaxAverage.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(cloudMode: Bool) async throws(RuuviCloudError) -> Bool {
        var outcome: Result<Bool, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .cloudModeEnabled,
            value: cloudMode.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(cloudMode)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.cloudModeEnabled.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(dashboard: Bool) async throws(RuuviCloudError) -> Bool {
        var outcome: Result<Bool, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardEnabled,
            value: dashboard.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(dashboard)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.dashboardEnabled.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(dashboardType: DashboardType) async throws(RuuviCloudError) -> DashboardType {
        var outcome: Result<DashboardType, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardType,
            value: dashboardType.rawValue,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(dashboardType)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.dashboardType.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(dashboardTapActionType: DashboardTapActionType) async throws(RuuviCloudError)
        -> DashboardTapActionType
    {
        var outcome: Result<DashboardTapActionType, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardTapActionType,
            value: dashboardTapActionType.rawValue,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(dashboardTapActionType)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.dashboardTapActionType.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(disableEmailAlert: Bool) async throws(RuuviCloudError) -> Bool {
        var outcome: Result<Bool, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .emailAlertDisabled,
            value: disableEmailAlert.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(disableEmailAlert)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.emailAlertDisabled.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(disablePushAlert: Bool) async throws(RuuviCloudError) -> Bool {
        var outcome: Result<Bool, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .pushAlertDisabled,
            value: disablePushAlert.chartBoolSettingString,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(disablePushAlert)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.pushAlertDisabled.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
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
        var outcome: Result<String, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .profileLanguageCode,
            value: profileLanguageCode,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(profileLanguageCode)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.profileLanguageCode.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func set(dashboardSensorOrder: [String]) async throws(RuuviCloudError) -> [String] {
        var outcome: Result<[String], RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiPostSettingRequest(
            name: .dashboardSensorOrder,
            value: RuuviCloudApiHelper.jsonStringFromArray(dashboardSensorOrder),
            timestamp: Int(Date().timeIntervalSince1970)
        )
        do {
            let _ = try await api.postSetting(request, authorization: apiKey)
            outcome = .success(dashboardSensorOrder)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .settings,
                uniqueKey: RuuviCloudApiSetting.dashboardSensorOrder.rawValue
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func getCloudSettings() async throws(RuuviCloudError) -> RuuviCloudSettings? {
        var outcome: Result<RuuviCloudSettings?, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiGetSettingsRequest()
        do {
            let response = try await api.getSettings(request, authorization: apiKey)
            outcome = .success(response.settings)
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func resetImage(
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> Void {
        var outcome: Result<Void, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiSensorImageUploadRequest(
            sensor: macId.value,
            action: .reset
        )
        do {
            let _ = try await api.resetImage(request, authorization: apiKey)
            outcome = .success(())
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .uploadImage,
                uniqueKey: macId.value + "-uploadImage"
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @MainActor
    public func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> URL {
        var outcome: Result<URL, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
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
            outcome = .success(response.uploadURL)
        } catch let error {
            let uniqueKey = macId.value + "-uploadImage"
            await self.createQueuedRequest(
                from: requestModel,
                additionalData: imageData,
                type: .uploadImage,
                uniqueKey: uniqueKey
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        var outcome: Result<AnyRuuviTagSensor, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }

        guard types.count == values.count else {
            outcome = .failure(.api(.badParameters))
            return try outcome.get()
        }

        let request = RuuviCloudApiPostSensorSettingsRequest(
            sensor: sensor.id,
            type: types,
            value: values,
            timestamp: timestamp ?? Int(Date().timeIntervalSince1970)
        )

        do {
            let _ = try await api.postSensorSettings(request, authorization: apiKey)
            outcome = .success(sensor.any)
        } catch let error {
            await self.createQueuedRequest(
                from: request,
                type: .sensorSettings,
                uniqueKey: sensor.id + "-sensor-settings"
            )
            outcome = .failure(.api(error))
        }

        return try outcome.get()
    }

    @MainActor
    public func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        var outcome: Result<AnyRuuviTagSensor, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
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
            let _ = try await api.update(request, authorization: apiKey)
            outcome = .success(sensor.any)
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

            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @MainActor
    public func update(
        name: String,
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        notifyListener(state: .loading, macId: sensor.id)
        var outcome: Result<AnyRuuviTagSensor, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            notifyListener(state: .failed, macId: sensor.id)
            return try outcome.get()
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
            let _ = try await api.update(request, authorization: apiKey)
            outcome = .success(sensor.with(name: name).any)
            self.notifyListener(state: .success, macId: sensor.id)
        } catch let error {
            let uniqueKey = sensor.id + "-name"
            await self.createQueuedRequest(
                from: request,
                type: .sensor,
                uniqueKey: uniqueKey
            )
            outcome = .failure(.api(error))
            self.notifyListener(state: .failed, macId: sensor.id)
        }
        return try outcome.get()
    }

    @MainActor
    public func loadShared(for sensor: RuuviTagSensor) async throws(RuuviCloudError) -> Set<AnyShareableSensor> {
        var outcome: Result<Set<AnyShareableSensor>, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiGetSensorsRequest(sensor: sensor.id)
        do {
            let response = try await api.sensors(request, authorization: apiKey)
            let arrayOfAny = response.sensors?.map(\.shareableSensor.any)
            let setOfAny = Set<AnyShareableSensor>(arrayOfAny ?? [])
            outcome = .success(setOfAny)
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func checkOwner(macId: MACIdentifier) async throws(RuuviCloudError) -> (String?, String?) {
        var outcome: Result<(String?, String?), RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiGetSensorsRequest(sensor: macId.mac)
        do {
            let response = try await api.owner(request, authorization: apiKey)
            outcome = .success((response.email, response.sensor))
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
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
        var outcome: Result<[RuuviCloudSensorDense], RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
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
            outcome = .success(arrayOfAny ?? [])
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @MainActor
    public func share(macId: MACIdentifier, with email: String) async throws(RuuviCloudError) -> ShareSensorResponse {
        var outcome: Result<ShareSensorResponse, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
        do {
            let response = try await api.share(request, authorization: apiKey)
            let result = ShareSensorResponse(
                macId: response.sensor?.mac,
                invited: response.invited
            )
            outcome = .success(result)
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @MainActor
    public func unshare(macId: MACIdentifier, with email: String?) async throws(RuuviCloudError) -> MACIdentifier {
        var outcome: Result<MACIdentifier, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiShareRequest(user: email, sensor: macId.value)
        do {
            let _ = try await api.unshare(request, authorization: apiKey)
            outcome = .success(macId)
        } catch let error {
            // A nil recipient removes the current user's share and also needs an offline retry.
            let uniqueKey = macId.mac + "-unshare-" + (email ?? "$self")
            await self.createQueuedRequest(
                from: request,
                type: .unshare,
                uniqueKey: uniqueKey
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @MainActor
    public func claim(
        name: String,
        macId: MACIdentifier
    ) async throws(RuuviCloudError) -> MACIdentifier? {
        var outcome: Result<MACIdentifier?, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiClaimRequest(name: name, sensor: macId.value)
        do {
            let response = try await api.claim(request, authorization: apiKey)
            outcome = .success(response.sensor?.mac)
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @discardableResult
    @MainActor
    public func contest(
        macId: MACIdentifier,
        secret: String
    ) async throws(RuuviCloudError) -> MACIdentifier? {
        var outcome: Result<MACIdentifier?, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiContestRequest(sensor: macId.value, secret: secret)
        do {
            let response = try await api.contest(request, authorization: apiKey)
            outcome = .success(response.sensor?.mac)
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @MainActor
    public func unclaim(
        macId: MACIdentifier,
        removeCloudHistory: Bool
    ) async throws(RuuviCloudError) -> MACIdentifier {
        var outcome: Result<MACIdentifier, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiUnclaimRequest(
            sensor: macId.value,
            deleteData: removeCloudHistory
        )
        do {
            let _ = try await api.unclaim(request, authorization: apiKey)
            outcome = .success(macId)
        } catch let error {
            let uniqueKey = macId.mac + "-unclaim"
            await self.createQueuedRequest(
                from: request,
                type: .unclaim,
                uniqueKey: uniqueKey
            )
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @MainActor
    public func requestCode(email: String) async throws(RuuviCloudError) -> String? {
        var outcome: Result<String?, RuuviCloudError>
        let request = RuuviCloudApiRegisterRequest(email: email)
        do {
            let response = try await api.register(request)
            outcome = .success(response.email)
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
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
        var outcome: Result<Bool, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudApiAccountDeleteRequest(email: email)
        do {
            let response = try await api.deleteAccount(
                request,
                authorization: apiKey
            )
            outcome = .success(response.email == email)
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @MainActor
    public func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws(RuuviCloudError) -> Int {
        var outcome: Result<Int, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
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
            outcome = .success(response.id)
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @MainActor
    public func unregisterPNToken(
        token: String?,
        tokenId: Int?
    ) async throws(RuuviCloudError) -> Bool {
        var outcome: Result<Bool, RuuviCloudError>
        let request = RuuviCloudPNTokenUnregisterRequest(
            token: token,
            id: tokenId
        )
        do {
            let _ = try await api.unregisterPNToken(
                request,
                authorization: user.apiKey
            )
            outcome = .success(true)
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @MainActor
    public func listPNTokens() async throws(RuuviCloudError) -> [RuuviCloudPNToken] {
        var outcome: Result<[RuuviCloudPNToken], RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        let request = RuuviCloudPNTokenListRequest()
        do {
            let response = try await api.listPNTokens(
                request,
                authorization: apiKey
            )
            let tokens = response.anyTokens
            outcome = .success(tokens)
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
    }

    @MainActor
    public func loadSensors() async throws(RuuviCloudError) -> [AnyCloudSensor] {
        var outcome: Result<[AnyCloudSensor], RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }
        do {
            let response = try await api.user(authorization: apiKey)
            let email = response.email
            let sensors = response.sensors.map { $0.with(email: email).any }
            outcome = .success(sensors)
        } catch let error {
            outcome = .failure(.api(error))
        }
        return try outcome.get()
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
        var outcome: Result<Bool, RuuviCloudError>
        guard let apiKey = user.apiKey
        else {
            outcome = .failure(.notAuthorized)
            return try outcome.get()
        }

        guard let type = request.type,
            let requestBody = request.requestBodyData
        else {
            outcome = .failure(.api(.badParameters))
            return try outcome.get()
        }

        let decoder = JSONDecoder()
        switch type {
        case .sensor:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiSensorUpdateRequest.self,
                    from: requestBody
                )

                do {
                    let _ = try await api.update(request, authorization: apiKey)
                    outcome = .success(true)
                } catch let error {
                    outcome = .failure(.api(error))
                }
            } catch {
                outcome = .failure(.api(.parsing(error)))
            }
        case .unclaim:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiUnclaimRequest.self,
                    from: requestBody
                )

                do {
                    let _ = try await api.unclaim(request, authorization: apiKey)
                    outcome = .success(true)
                } catch let error {
                    outcome = .failure(.api(error))
                }
            } catch {
                outcome = .failure(.api(.parsing(error)))
            }
        case .unshare:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiShareRequest.self,
                    from: requestBody
                )

                do {
                    let _ = try await api.unshare(request, authorization: apiKey)
                    outcome = .success(true)
                } catch let error {
                    outcome = .failure(.api(error))
                }
            } catch {
                outcome = .failure(.api(.parsing(error)))
            }
        case .alert:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiPostAlertRequest.self,
                    from: requestBody
                )

                do {
                    let _ = try await api.postAlert(request, authorization: apiKey)
                    outcome = .success(true)
                } catch let error {
                    outcome = .failure(.api(error))
                }
            } catch {
                outcome = .failure(.api(.parsing(error)))
            }
        case .settings:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiPostSettingRequest.self,
                    from: requestBody
                )

                do {
                    let _ = try await api.postSetting(request, authorization: apiKey)
                    outcome = .success(true)
                } catch let error {
                    outcome = .failure(.api(error))
                }
            } catch {
                outcome = .failure(.api(.parsing(error)))
            }
        case .sensorSettings:
            do {
                let request = try decoder.decode(
                    RuuviCloudApiPostSensorSettingsRequest.self,
                    from: requestBody
                )

                do {
                    let _ = try await api.postSensorSettings(request, authorization: apiKey)
                    outcome = .success(true)
                } catch let error {
                    outcome = .failure(.api(error))
                }
            } catch {
                outcome = .failure(.api(.parsing(error)))
            }
        case .uploadImage:
            do {
                let requestModel = try decoder.decode(
                    RuuviCloudApiSensorImageUploadRequest.self,
                    from: requestBody
                )

                if requestModel.action == .reset {
                    do {
                        let _ = try await api.resetImage(requestModel, authorization: apiKey)
                        outcome = .success(true)
                    } catch let error {
                        outcome = .failure(.api(error))
                    }
                } else if let imageData = request.additionalData {
                    do {
                        let _ = try await api.uploadImage(
                            requestModel,
                            imageData: imageData,
                            authorization: apiKey,
                            uploadProgress: nil
                        )
                        outcome = .success(true)
                    } catch let error {
                        outcome = .failure(.api(error))
                    }
                } else {
                    outcome = .failure(.api(.badParameters))
                }
            } catch {
                outcome = .failure(.api(.parsing(error)))
            }
        default:
            outcome = .failure(.api(.badParameters))
        }
        return try outcome.get()
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
