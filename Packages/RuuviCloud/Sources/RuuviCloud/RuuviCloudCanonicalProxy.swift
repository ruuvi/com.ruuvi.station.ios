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

    public func requestCode(email: String) async throws -> String? {
        try await cloud.requestCode(email: email)
    }

    public func validateCode(code: String) async throws -> ValidateCodeResponse {
        try await cloud.validateCode(code: code)
    }

    public func deleteAccount(email: String) async throws -> Bool {
        try await cloud.deleteAccount(email: email)
    }

    public func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws -> Int {
        try await cloud.registerPNToken(
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
    ) async throws -> Bool {
        try await cloud.unregisterPNToken(token: token, tokenId: tokenId)
    }

    public func listPNTokens() async throws -> [RuuviCloudPNToken] {
        try await cloud.listPNTokens()
    }

    public func loadSensors() async throws -> [AnyCloudSensor] {
        try await cloud.loadSensors()
    }

    // swiftlint:disable:next function_parameter_count
    public func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) async throws -> [RuuviCloudSensorDense] {
        var sensorForCloud: RuuviTagSensor?
        if let sensor {
            sensorForCloud = await canonicalizedSensor(sensor)
        }
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
    ) async throws -> [AnyRuuviTagSensorRecord] {
        try await cloud.loadRecords(
            macId: await canonical(macId),
            since: since,
            until: until
        )
    }

    public func claim(
        name: String,
        macId: MACIdentifier
    ) async throws -> MACIdentifier? {
        let response = try await cloud.claim(
            name: name,
            macId: await canonical(macId)
        )
        if let response {
            return await original(for: response, fallback: macId)
        }
        return nil
    }

    public func contest(
        macId: MACIdentifier,
        secret: String
    ) async throws -> MACIdentifier? {
        let response = try await cloud.contest(
            macId: await canonical(macId),
            secret: secret
        )
        if let response {
            return await original(for: response, fallback: macId)
        }
        return nil
    }

    public func unclaim(
        macId: MACIdentifier,
        removeCloudHistory: Bool
    ) async throws -> MACIdentifier {
        let response = try await cloud.unclaim(
            macId: await canonical(macId),
            removeCloudHistory: removeCloudHistory
        )
        return await original(for: response, fallback: macId)
    }

    public func share(
        macId: MACIdentifier,
        with email: String
    ) async throws -> ShareSensorResponse {
        let response = try await cloud.share(
            macId: await canonical(macId),
            with: email
        )
        var adjusted = response
        if let returnedMac = response.macId {
            adjusted.macId = await original(for: returnedMac, fallback: macId)
        } else {
            adjusted.macId = macId
        }
        return adjusted
    }

    public func unshare(
        macId: MACIdentifier,
        with email: String?
    ) async throws -> MACIdentifier {
        let response = try await cloud.unshare(
            macId: await canonical(macId),
            with: email
        )
        return await original(for: response, fallback: macId)
    }

    public func loadShared(
        for sensor: RuuviTagSensor
    ) async throws -> Set<AnyShareableSensor> {
        try await cloud.loadShared(for: await canonicalizedSensor(sensor))
    }

    public func checkOwner(macId: MACIdentifier) async throws -> (String?, String?) {
        try await cloud.checkOwner(macId: await canonical(macId))
    }

    public func update(
        name: String,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor {
        let updated = try await cloud.update(
            name: name,
            for: await canonicalizedSensor(sensor)
        )
        return await restore(sensor: updated, originalMac: sensor.macId)
    }

    public func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws -> URL {
        let canonicalMac = await canonical(macId)
        let wrappedProgress: ((MACIdentifier, Double) -> Void)?
        if let progress {
            wrappedProgress = { mac, value in
                // Note: Can't use await in closure, so we use the fallback
                progress(macId, value)
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
    ) async throws -> Void {
        try await cloud.resetImage(for: await canonical(macId))
    }

    public func getCloudSettings() async throws -> RuuviCloudSettings? {
        try await cloud.getCloudSettings()
    }

    public func set(temperatureUnit: TemperatureUnit) async throws -> TemperatureUnit {
        try await cloud.set(temperatureUnit: temperatureUnit)
    }

    public func set(temperatureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        try await cloud.set(temperatureAccuracy: temperatureAccuracy)
    }

    public func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit {
        try await cloud.set(humidityUnit: humidityUnit)
    }

    public func set(humidityAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        try await cloud.set(humidityAccuracy: humidityAccuracy)
    }

    public func set(pressureUnit: UnitPressure) async throws -> UnitPressure {
        try await cloud.set(pressureUnit: pressureUnit)
    }

    public func set(pressureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        try await cloud.set(pressureAccuracy: pressureAccuracy)
    }

    public func set(showAllData: Bool) async throws -> Bool {
        try await cloud.set(showAllData: showAllData)
    }

    public func set(drawDots: Bool) async throws -> Bool {
        try await cloud.set(drawDots: drawDots)
    }

    public func set(chartDuration: Int) async throws -> Int {
        try await cloud.set(chartDuration: chartDuration)
    }

    public func set(showMinMaxAvg: Bool) async throws -> Bool {
        try await cloud.set(showMinMaxAvg: showMinMaxAvg)
    }

    public func set(cloudMode: Bool) async throws -> Bool {
        try await cloud.set(cloudMode: cloudMode)
    }

    public func set(dashboard: Bool) async throws -> Bool {
        try await cloud.set(dashboard: dashboard)
    }

    public func set(dashboardType: DashboardType) async throws -> DashboardType {
        try await cloud.set(dashboardType: dashboardType)
    }

    public func set(dashboardTapActionType: DashboardTapActionType) async throws -> DashboardTapActionType {
        try await cloud.set(dashboardTapActionType: dashboardTapActionType)
    }

    public func set(disableEmailAlert: Bool) async throws -> Bool {
        try await cloud.set(disableEmailAlert: disableEmailAlert)
    }

    public func set(disablePushAlert: Bool) async throws -> Bool {
        try await cloud.set(disablePushAlert: disablePushAlert)
    }

    public func set(profileLanguageCode: String) async throws -> String {
        try await cloud.set(profileLanguageCode: profileLanguageCode)
    }

    public func set(dashboardSensorOrder: [String]) async throws -> [String] {
        try await cloud.set(dashboardSensorOrder: dashboardSensorOrder)
    }

    public func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws -> AnyRuuviTagSensor {
        let updated = try await cloud.updateSensorSettings(
            for: await canonicalizedSensor(sensor),
            types: types,
            values: values,
            timestamp: timestamp
        )
        return await restore(sensor: updated, originalMac: sensor.macId)
    }

    public func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor {
        let updated = try await cloud.update(
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset,
            for: await canonicalizedSensor(sensor)
        )
        return await restore(sensor: updated, originalMac: sensor.macId)
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
    ) async throws -> Void {
        try await cloud.setAlert(
            type: type,
            settingType: settingType,
            isEnabled: isEnabled,
            min: min,
            max: max,
            counter: counter,
            delay: delay,
            description: description,
            for: await canonical(macId)
        )
    }

    public func loadAlerts() async throws -> [RuuviCloudSensorAlerts] {
        try await cloud.loadAlerts()
    }

    public func executeQueuedRequest(from request: RuuviCloudQueuedRequest) async throws -> Bool {
        try await cloud.executeQueuedRequest(from: request)
    }
}

private extension RuuviCloudCanonicalProxy {
    func canonical(_ mac: MACIdentifier) async -> MACIdentifier {
        await localIDs.fullMac(for: mac) ?? mac
    }

    func canonicalizedSensor(_ sensor: RuuviTagSensor) async -> RuuviTagSensor {
        guard let mac = sensor.macId else {
            return sensor
        }
        let canonicalMac = await canonical(mac)
        guard canonicalMac.value != mac.value else {
            return sensor
        }
        return sensor.with(macId: canonicalMac)
    }

    func original(for mac: MACIdentifier, fallback: MACIdentifier) async -> MACIdentifier {
        await localIDs.originalMac(for: mac) ?? fallback
    }

    func restore(sensor: AnyRuuviTagSensor, originalMac: MACIdentifier?) async -> AnyRuuviTagSensor {
        guard let originalMac else {
            return sensor
        }
        guard let currentMac = sensor.macId else {
            return sensor
        }
        let restored = await original(for: currentMac, fallback: originalMac)
        if restored.value == currentMac.value {
            return sensor
        }
        return sensor.with(macId: restored).any
    }
}

// swiftlint:enable file_length
