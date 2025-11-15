// swiftlint:disable file_length

import Foundation
import Future
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

    public func requestCode(email: String) -> Future<String?, RuuviCloudError> {
        cloud.requestCode(email: email)
    }

    public func validateCode(code: String) -> Future<ValidateCodeResponse, RuuviCloudError> {
        cloud.validateCode(code: code)
    }

    public func deleteAccount(email: String) -> Future<Bool, RuuviCloudError> {
        cloud.deleteAccount(email: email)
    }

    public func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) -> Future<Int, RuuviCloudError> {
        cloud.registerPNToken(
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
    ) -> Future<Bool, RuuviCloudError> {
        cloud.unregisterPNToken(token: token, tokenId: tokenId)
    }

    public func listPNTokens() -> Future<[RuuviCloudPNToken], RuuviCloudError> {
        cloud.listPNTokens()
    }

    public func loadSensors() -> Future<[AnyCloudSensor], RuuviCloudError> {
        cloud.loadSensors()
    }

    // swiftlint:disable:next function_parameter_count
    public func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) -> Future<[RuuviCloudSensorDense], RuuviCloudError> {
        let sensorForCloud = sensor.map { canonicalizedSensor($0) }
        return cloud.loadSensorsDense(
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
    ) -> Future<[AnyRuuviTagSensorRecord], RuuviCloudError> {
        cloud.loadRecords(
            macId: canonical(macId),
            since: since,
            until: until
        )
    }

    public func claim(
        name: String,
        macId: MACIdentifier
    ) -> Future<MACIdentifier?, RuuviCloudError> {
        let promise = Promise<MACIdentifier?, RuuviCloudError>()
        cloud.claim(
            name: name,
            macId: canonical(macId)
        )
        .on(success: { [weak self] response in
            guard let self else { return }
            let restored = response.map { self.original(for: $0, fallback: macId) }
            promise.succeed(value: restored)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    public func contest(
        macId: MACIdentifier,
        secret: String
    ) -> Future<MACIdentifier?, RuuviCloudError> {
        let promise = Promise<MACIdentifier?, RuuviCloudError>()
        cloud.contest(
            macId: canonical(macId),
            secret: secret
        )
        .on(success: { [weak self] response in
            guard let self else { return }
            let restored = response.map { self.original(for: $0, fallback: macId) }
            promise.succeed(value: restored)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    public func unclaim(
        macId: MACIdentifier,
        removeCloudHistory: Bool
    ) -> Future<MACIdentifier, RuuviCloudError> {
        let promise = Promise<MACIdentifier, RuuviCloudError>()
        cloud.unclaim(
            macId: canonical(macId),
            removeCloudHistory: removeCloudHistory
        )
        .on(success: { [weak self] response in
            guard let self else { return }
            promise.succeed(value: self.original(for: response, fallback: macId))
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    public func share(
        macId: MACIdentifier,
        with email: String
    ) -> Future<ShareSensorResponse, RuuviCloudError> {
        let promise = Promise<ShareSensorResponse, RuuviCloudError>()
        cloud.share(
            macId: canonical(macId),
            with: email
        )
        .on(success: { [weak self] response in
            guard let self else { return }
            var adjusted = response
            if let returnedMac = response.macId {
                adjusted.macId = self.original(for: returnedMac, fallback: macId)
            } else {
                adjusted.macId = macId
            }
            promise.succeed(value: adjusted)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    public func unshare(
        macId: MACIdentifier,
        with email: String?
    ) -> Future<MACIdentifier, RuuviCloudError> {
        let promise = Promise<MACIdentifier, RuuviCloudError>()
        cloud.unshare(
            macId: canonical(macId),
            with: email
        )
        .on(success: { [weak self] response in
            guard let self else { return }
            promise.succeed(value: self.original(for: response, fallback: macId))
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    public func loadShared(
        for sensor: RuuviTagSensor
    ) -> Future<Set<AnyShareableSensor>, RuuviCloudError> {
        cloud.loadShared(for: canonicalizedSensor(sensor))
    }

    public func checkOwner(macId: MACIdentifier) -> Future<(String?, String?), RuuviCloudError> {
        cloud.checkOwner(macId: canonical(macId))
    }

    public func update(
        name: String,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensor, RuuviCloudError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviCloudError>()
        let originalMacId = sensor.macId
        cloud.update(
            name: name,
            for: canonicalizedSensor(sensor)
        )
        .on(success: { [weak self] updated in
            guard let self else { return }
            let restored = self.restore(sensor: updated, originalMac: originalMacId)
            promise.succeed(value: restored)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    public func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) -> Future<URL, RuuviCloudError> {
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
        return cloud.upload(
            imageData: imageData,
            mimeType: mimeType,
            progress: wrappedProgress,
            for: canonicalMac
        )
    }

    public func resetImage(
        for macId: MACIdentifier
    ) -> Future<Void, RuuviCloudError> {
        cloud.resetImage(for: canonical(macId))
    }

    public func getCloudSettings() -> Future<RuuviCloudSettings?, RuuviCloudError> {
        cloud.getCloudSettings()
    }

    public func set(temperatureUnit: TemperatureUnit) -> Future<TemperatureUnit, RuuviCloudError> {
        cloud.set(temperatureUnit: temperatureUnit)
    }

    public func set(temperatureAccuracy: MeasurementAccuracyType) -> Future<MeasurementAccuracyType, RuuviCloudError> {
        cloud.set(temperatureAccuracy: temperatureAccuracy)
    }

    public func set(humidityUnit: HumidityUnit) -> Future<HumidityUnit, RuuviCloudError> {
        cloud.set(humidityUnit: humidityUnit)
    }

    public func set(humidityAccuracy: MeasurementAccuracyType) -> Future<MeasurementAccuracyType, RuuviCloudError> {
        cloud.set(humidityAccuracy: humidityAccuracy)
    }

    public func set(pressureUnit: UnitPressure) -> Future<UnitPressure, RuuviCloudError> {
        cloud.set(pressureUnit: pressureUnit)
    }

    public func set(pressureAccuracy: MeasurementAccuracyType) -> Future<MeasurementAccuracyType, RuuviCloudError> {
        cloud.set(pressureAccuracy: pressureAccuracy)
    }

    public func set(showAllData: Bool) -> Future<Bool, RuuviCloudError> {
        cloud.set(showAllData: showAllData)
    }

    public func set(drawDots: Bool) -> Future<Bool, RuuviCloudError> {
        cloud.set(drawDots: drawDots)
    }

    public func set(chartDuration: Int) -> Future<Int, RuuviCloudError> {
        cloud.set(chartDuration: chartDuration)
    }

    public func set(showMinMaxAvg: Bool) -> Future<Bool, RuuviCloudError> {
        cloud.set(showMinMaxAvg: showMinMaxAvg)
    }

    public func set(cloudMode: Bool) -> Future<Bool, RuuviCloudError> {
        cloud.set(cloudMode: cloudMode)
    }

    public func set(dashboard: Bool) -> Future<Bool, RuuviCloudError> {
        cloud.set(dashboard: dashboard)
    }

    public func set(dashboardType: DashboardType) -> Future<DashboardType, RuuviCloudError> {
        cloud.set(dashboardType: dashboardType)
    }

    public func set(dashboardTapActionType: DashboardTapActionType) -> Future<DashboardTapActionType, RuuviCloudError> {
        cloud.set(dashboardTapActionType: dashboardTapActionType)
    }

    public func set(disableEmailAlert: Bool) -> Future<Bool, RuuviCloudError> {
        cloud.set(disableEmailAlert: disableEmailAlert)
    }

    public func set(disablePushAlert: Bool) -> Future<Bool, RuuviCloudError> {
        cloud.set(disablePushAlert: disablePushAlert)
    }

    public func set(profileLanguageCode: String) -> Future<String, RuuviCloudError> {
        cloud.set(profileLanguageCode: profileLanguageCode)
    }

    public func set(dashboardSensorOrder: [String]) -> Future<[String], RuuviCloudError> {
        cloud.set(dashboardSensorOrder: dashboardSensorOrder)
    }

    public func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) -> Future<AnyRuuviTagSensor, RuuviCloudError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviCloudError>()
        let originalMacId = sensor.macId
        cloud.updateSensorSettings(
            for: canonicalizedSensor(
                sensor
            ),
            types: types,
            values: values,
            timestamp: timestamp
        )
        .on(success: { [weak self] updated in
            guard let self else { return }
            let restored = self.restore(sensor: updated, originalMac: originalMacId)
            promise.succeed(value: restored)
        }, failure: { error in
            promise.fail(error: error)
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
        let originalMacId = sensor.macId
        cloud.update(
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset,
            for: canonicalizedSensor(sensor)
        )
        .on(success: { [weak self] updated in
            guard let self else { return }
            let restored = self.restore(sensor: updated, originalMac: originalMacId)
            promise.succeed(value: restored)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
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
    ) -> Future<Void, RuuviCloudError> {
        cloud.setAlert(
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

    public func loadAlerts() -> Future<[RuuviCloudSensorAlerts], RuuviCloudError> {
        cloud.loadAlerts()
    }

    public func executeQueuedRequest(from request: RuuviCloudQueuedRequest) -> Future<Bool, RuuviCloudError> {
        cloud.executeQueuedRequest(from: request)
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
