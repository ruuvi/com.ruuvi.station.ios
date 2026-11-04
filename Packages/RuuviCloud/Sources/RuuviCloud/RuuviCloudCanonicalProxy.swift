#if SWIFT_PACKAGE
    import RuuviPool
    import RuuviUser
#endif
// swiftlint:disable file_length

import Foundation
import RuuviLocal
import RuuviOntology

// A proxy for RuuviCloud that translates between local and canonical MAC identifiers.
// Canonical MAC identifiers are used in the cloud when local MAC identifiers is not
// full MAC address.
// swiftlint:disable:next type_body_length
public final class RuuviCloudCanonicalProxy: RuuviCloud {
    private let cloud: RuuviCloud
    private let localIDs: RuuviLocalIDs

    public init(cloud: RuuviCloud, localIDs: RuuviLocalIDs) {
        self.cloud = cloud
        self.localIDs = localIDs
    }

    public func requestCode(email: String) async throws(RuuviCloudError) -> String? {
        return try await cloud.requestCode(email: email)
    }

    public func validateCode(code: String) async throws(RuuviCloudError) -> ValidateCodeResponse {
        return try await cloud.validateCode(code: code)
    }

    public func deleteAccount(email: String) async throws(RuuviCloudError) -> Bool {
        return try await cloud.deleteAccount(email: email)
    }

    public func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws(RuuviCloudError) -> Int {
        return try await cloud.registerPNToken(
            token: token,
            type: type,
            name: name,
            data: data,
            params: params
        )
    }

    public func unregisterPNToken(
        token: String?,
        tokenId: Int?
    ) async throws(RuuviCloudError) -> Bool {
        return try await cloud.unregisterPNToken(token: token, tokenId: tokenId)
    }

    public func listPNTokens() async throws(RuuviCloudError) -> [RuuviCloudPNToken] {
        return try await cloud.listPNTokens()
    }

    public func loadSensors() async throws(RuuviCloudError) -> [AnyCloudSensor] {
        return try await cloud.loadSensors()
    }

    // swiftlint:disable:next function_parameter_count
    public func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) async throws(RuuviCloudError) -> [RuuviCloudSensorDense] {
        let sensorForCloud = sensor.map { canonicalizedSensor($0) }
        return try await cloud.loadSensorsDense(
            for: sensorForCloud,
            measurements: measurements,
            sharedToOthers: sharedToOthers,
            sharedToMe: sharedToMe,
            alerts: alerts,
            settings: settings
        )
    }

    public func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws(RuuviCloudError) -> [AnyRuuviTagSensorRecord] {
        return try await cloud.loadRecords(
            macId: canonical(macId),
            since: since,
            until: until
        )
    }

    public func claim(
        name: String,
        macId: MACIdentifier
    ) async throws(RuuviCloudError) -> MACIdentifier? {
        var outcome: Result<MACIdentifier?, RuuviCloudError>
        do {
            let response = try await cloud.claim(
                name: name,
                macId: canonical(macId)
            )
            let restored = response.map { self.original(for: $0, fallback: macId) }
            outcome = .success(restored)
        } catch let error {
            outcome = .failure(error)
        }
        return try outcome.get()
    }

    public func contest(
        macId: MACIdentifier,
        secret: String
    ) async throws(RuuviCloudError) -> MACIdentifier? {
        var outcome: Result<MACIdentifier?, RuuviCloudError>
        do {
            let response = try await cloud.contest(
                macId: canonical(macId),
                secret: secret
            )
            let restored = response.map { self.original(for: $0, fallback: macId) }
            outcome = .success(restored)
        } catch let error {
            outcome = .failure(error)
        }
        return try outcome.get()
    }

    public func unclaim(
        macId: MACIdentifier,
        removeCloudHistory: Bool
    ) async throws(RuuviCloudError) -> MACIdentifier {
        var outcome: Result<MACIdentifier, RuuviCloudError>
        do {
            let response = try await cloud.unclaim(
                macId: canonical(macId),
                removeCloudHistory: removeCloudHistory
            )
            outcome = .success(self.original(for: response, fallback: macId))
        } catch let error {
            outcome = .failure(error)
        }
        return try outcome.get()
    }

    public func share(
        macId: MACIdentifier,
        with email: String
    ) async throws(RuuviCloudError) -> ShareSensorResponse {
        var outcome: Result<ShareSensorResponse, RuuviCloudError>
        do {
            let response = try await cloud.share(
                macId: canonical(macId),
                with: email
            )
            var adjusted = response
            if let returnedMac = response.macId {
                adjusted.macId = self.original(for: returnedMac, fallback: macId)
            } else {
                adjusted.macId = macId
            }
            outcome = .success(adjusted)
        } catch let error {
            outcome = .failure(error)
        }
        return try outcome.get()
    }

    public func unshare(
        macId: MACIdentifier,
        with email: String?
    ) async throws(RuuviCloudError) -> MACIdentifier {
        var outcome: Result<MACIdentifier, RuuviCloudError>
        do {
            let response = try await cloud.unshare(
                macId: canonical(macId),
                with: email
            )
            outcome = .success(self.original(for: response, fallback: macId))
        } catch let error {
            outcome = .failure(error)
        }
        return try outcome.get()
    }

    public func loadShared(
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> Set<AnyShareableSensor> {
        return try await cloud.loadShared(for: canonicalizedSensor(sensor))
    }

    public func checkOwner(macId: MACIdentifier) async throws(RuuviCloudError) -> (String?, String?) {
        return try await cloud.checkOwner(macId: canonical(macId))
    }

    public func update(
        name: String,
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        var outcome: Result<AnyRuuviTagSensor, RuuviCloudError>
        let originalMacId = sensor.macId
        do {
            let updated = try await cloud.update(
                name: name,
                for: canonicalizedSensor(sensor)
            )
            let restored = self.restore(sensor: updated, originalMac: originalMacId)
            outcome = .success(restored)
        } catch let error {
            outcome = .failure(error)
        }
        return try outcome.get()
    }

    public func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> URL {
        let canonicalMac = canonical(macId)
        let wrappedProgress: ((MACIdentifier, Double) -> Void)?
        if let progress {
            wrappedProgress = { [weak self] mac, value in
                guard let self else {
                    progress(mac, value)
                    return
                }
                let originalMac = self.original(for: mac, fallback: macId)
                progress(originalMac, value)
            }
        } else {
            wrappedProgress = nil
        }
        return try await cloud.upload(
            imageData: imageData,
            mimeType: mimeType,
            progress: wrappedProgress,
            for: canonicalMac
        )
    }

    public func resetImage(
        for macId: MACIdentifier
    ) async throws(RuuviCloudError) -> Void {
        return try await cloud.resetImage(for: canonical(macId))
    }

    public func getCloudSettings() async throws(RuuviCloudError) -> RuuviCloudSettings? {
        return try await cloud.getCloudSettings()
    }

    public func set(temperatureUnit: TemperatureUnit) async throws(RuuviCloudError) -> TemperatureUnit {
        return try await cloud.set(temperatureUnit: temperatureUnit)
    }

    public func set(temperatureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError)
        -> MeasurementAccuracyType
    {
        return try await cloud.set(temperatureAccuracy: temperatureAccuracy)
    }

    public func set(humidityUnit: HumidityUnit) async throws(RuuviCloudError) -> HumidityUnit {
        return try await cloud.set(humidityUnit: humidityUnit)
    }

    public func set(humidityAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType
    {
        return try await cloud.set(humidityAccuracy: humidityAccuracy)
    }

    public func set(userSetting: RuuviCloudApiSetting, value: String) async throws(RuuviCloudError) -> String {
        return try await cloud.set(userSetting: userSetting, value: value)
    }

    public func set(pressureUnit: UnitPressure) async throws(RuuviCloudError) -> UnitPressure {
        return try await cloud.set(pressureUnit: pressureUnit)
    }

    public func set(pressureAccuracy: MeasurementAccuracyType) async throws(RuuviCloudError) -> MeasurementAccuracyType
    {
        return try await cloud.set(pressureAccuracy: pressureAccuracy)
    }

    public func set(showAllData: Bool) async throws(RuuviCloudError) -> Bool {
        return try await cloud.set(showAllData: showAllData)
    }

    public func set(drawDots: Bool) async throws(RuuviCloudError) -> Bool {
        return try await cloud.set(drawDots: drawDots)
    }

    public func set(chartDuration: Int) async throws(RuuviCloudError) -> Int {
        return try await cloud.set(chartDuration: chartDuration)
    }

    public func set(showMinMaxAvg: Bool) async throws(RuuviCloudError) -> Bool {
        return try await cloud.set(showMinMaxAvg: showMinMaxAvg)
    }

    public func set(cloudMode: Bool) async throws(RuuviCloudError) -> Bool {
        return try await cloud.set(cloudMode: cloudMode)
    }

    public func set(dashboard: Bool) async throws(RuuviCloudError) -> Bool {
        return try await cloud.set(dashboard: dashboard)
    }

    public func set(dashboardType: DashboardType) async throws(RuuviCloudError) -> DashboardType {
        return try await cloud.set(dashboardType: dashboardType)
    }

    public func set(dashboardTapActionType: DashboardTapActionType) async throws(RuuviCloudError)
        -> DashboardTapActionType
    {
        return try await cloud.set(dashboardTapActionType: dashboardTapActionType)
    }

    public func set(disableEmailAlert: Bool) async throws(RuuviCloudError) -> Bool {
        return try await cloud.set(disableEmailAlert: disableEmailAlert)
    }

    public func set(disablePushAlert: Bool) async throws(RuuviCloudError) -> Bool {
        return try await cloud.set(disablePushAlert: disablePushAlert)
    }

    public func getMarketingConsent() async throws(RuuviCloudError) -> RuuviCloudMarketingConsent {
        return try await cloud.getMarketingConsent()
    }

    public func set(marketingPreference: Bool) async throws(RuuviCloudError) -> RuuviCloudMarketingConsent {
        return try await cloud.set(marketingPreference: marketingPreference)
    }

    public func set(profileLanguageCode: String) async throws(RuuviCloudError) -> String {
        return try await cloud.set(profileLanguageCode: profileLanguageCode)
    }

    public func set(dashboardSensorOrder: [String]) async throws(RuuviCloudError) -> [String] {
        return try await cloud.set(dashboardSensorOrder: dashboardSensorOrder)
    }

    public func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        var outcome: Result<AnyRuuviTagSensor, RuuviCloudError>
        let originalMacId = sensor.macId
        do {
            let updated = try await cloud.updateSensorSettings(
                for: canonicalizedSensor(
                    sensor
                ),
                types: types,
                values: values,
                timestamp: timestamp
            )
            let restored = self.restore(sensor: updated, originalMac: originalMacId)
            outcome = .success(restored)
        } catch let error {
            outcome = .failure(error)
        }
        return try outcome.get()
    }
    public func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws(RuuviCloudError) -> AnyRuuviTagSensor {
        var outcome: Result<AnyRuuviTagSensor, RuuviCloudError>
        let originalMacId = sensor.macId
        do {
            let updated = try await cloud.update(
                temperatureOffset: temperatureOffset,
                humidityOffset: humidityOffset,
                pressureOffset: pressureOffset,
                for: canonicalizedSensor(sensor)
            )
            let restored = self.restore(sensor: updated, originalMac: originalMacId)
            outcome = .success(restored)
        } catch let error {
            outcome = .failure(error)
        }
        return try outcome.get()
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
    ) async throws(RuuviCloudError) -> Void {
        return try await cloud.setAlert(
            type: type,
            settingType: settingType,
            isEnabled: isEnabled,
            min: min,
            max: max,
            counter: counter,
            delay: delay,
            description: description,
            for: canonical(macId)
        )
    }

    public func loadAlerts() async throws(RuuviCloudError) -> [RuuviCloudSensorAlerts] {
        return try await cloud.loadAlerts()
    }

    public func executeQueuedRequest(from request: RuuviCloudQueuedRequest) async throws(RuuviCloudError) -> Bool {
        return try await cloud.executeQueuedRequest(from: request)
    }
}

private extension RuuviCloudCanonicalProxy {
    func canonical(_ mac: MACIdentifier) -> MACIdentifier {
        localIDs.fullMac(for: mac) ?? mac
    }

    func canonicalizedSensor(_ sensor: RuuviTagSensor) -> RuuviTagSensor {
        guard let mac = sensor.macId else {
            return sensor
        }
        let canonicalMac = canonical(mac)
        guard canonicalMac.value != mac.value else {
            return sensor
        }
        return sensor.with(macId: canonicalMac)
    }

    func original(for mac: MACIdentifier, fallback: MACIdentifier) -> MACIdentifier {
        localIDs.originalMac(for: mac) ?? fallback
    }

    func restore(sensor: AnyRuuviTagSensor, originalMac: MACIdentifier?) -> AnyRuuviTagSensor {
        guard let originalMac else {
            return sensor
        }
        guard let currentMac = sensor.macId else {
            return sensor
        }
        let restored = original(for: currentMac, fallback: originalMac)
        if restored.value == currentMac.value {
            return sensor
        }
        return sensor.with(macId: restored).any
    }
}

// swiftlint:enable file_length
