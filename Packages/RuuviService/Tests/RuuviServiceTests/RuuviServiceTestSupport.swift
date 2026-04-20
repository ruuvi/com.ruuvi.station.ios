@testable import RuuviLocal
@testable import RuuviService
import Humidity
import RuuviCloud
import RuuviCore
import RuuviOntology
import RuuviPool
import RuuviRepository
import RuuviStorage
import RuuviUser
import UIKit
import XCTest

func resetTestUserDefaults() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys {
        UserDefaults.standard.removeObject(forKey: key)
    }
    if let appGroup = UserDefaults(suiteName: "group.com.ruuvi.station.pnservice") {
        for key in appGroup.dictionaryRepresentation().keys {
            appGroup.removeObject(forKey: key)
        }
    }
}

func makeSettings() -> RuuviLocalSettingsUserDefaults {
    let settings = RuuviLocalSettingsUserDefaults()
    settings.temperatureUnit = .celsius
    settings.temperatureAccuracy = .two
    settings.humidityUnit = .percent
    settings.humidityAccuracy = .two
    settings.pressureUnit = .hectopascals
    settings.pressureAccuracy = .two
    settings.language = .english
    settings.cloudProfileLanguageCode = nil
    settings.chartDownsamplingOn = false
    settings.chartDrawDotsOn = false
    settings.chartStatsOn = false
    settings.cloudModeEnabled = false
    settings.dashboardEnabled = false
    settings.dashboardType = .image
    settings.dashboardTapActionType = .card
    settings.pushAlertDisabled = false
    settings.emailAlertDisabled = false
    settings.marketingPreference = false
    settings.dashboardSensorOrder = []
    settings.includeDataSourceInHistoryExport = false
    settings.networkPruningIntervalHours = 24
    settings.setCardToOpenFromWidget(for: nil)
    settings.setLastOpenedChart(with: nil)
    return settings
}

func makeSensor(
    luid: String? = "luid-1",
    macId: String? = "AA:BB:CC:11:22:33",
    version: Int = 5,
    name: String = "Sensor",
    isCloud: Bool = false,
    isClaimed: Bool = false,
    isOwner: Bool = false,
    owner: String? = nil,
    lastUpdated: Date? = nil
) -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: version,
        firmwareVersion: "1.0.0",
        luid: luid?.luid,
        macId: macId?.mac,
        serviceUUID: nil,
        isConnectable: true,
        name: name,
        isClaimed: isClaimed,
        isOwner: isOwner,
        owner: owner,
        ownersPlan: nil,
        isCloudSensor: isCloud,
        canShare: isCloud,
        sharedTo: [],
        maxHistoryDays: nil,
        lastUpdated: lastUpdated
    )
}

func makeCloudSensor(
    id: String = "AA:BB:CC:11:22:33",
    name: String = "Cloud Sensor",
    isOwner: Bool = true,
    owner: String? = "owner@example.com",
    picture: URL? = nil
) -> CloudSensor {
    CloudSensorStruct(
        id: id,
        serviceUUID: nil,
        name: name,
        isClaimed: isOwner,
        isOwner: isOwner,
        owner: owner,
        ownersPlan: nil,
        picture: picture,
        offsetTemperature: nil,
        offsetHumidity: nil,
        offsetPressure: nil,
        isCloudSensor: true,
        canShare: true,
        sharedTo: [],
        maxHistoryDays: nil
    )
}

func makeRecord(
    luid: String? = "luid-1",
    macId: String? = "AA:BB:CC:11:22:33",
    version: Int = 5,
    date: Date = Date(),
    source: RuuviTagSensorRecordSource = .advertisement,
    temperature: Double? = nil,
    humidity: Double? = nil,
    pressure: Double? = nil,
    voltage: Double? = nil,
    acceleration: Acceleration? = nil,
    movementCounter: Int? = nil,
    measurementSequenceNumber: Int? = nil,
    rssi: Int? = -65,
    co2: Double? = nil,
    pm25: Double? = nil,
    pm1: Double? = nil,
    pm4: Double? = nil,
    pm10: Double? = nil,
    voc: Double? = nil,
    nox: Double? = nil,
    luminance: Double? = nil,
    dbaInstant: Double? = nil,
    dbaAvg: Double? = nil,
    dbaPeak: Double? = nil
) -> RuuviTagSensorRecord {
    RuuviTagSensorRecordStruct(
        luid: luid?.luid,
        date: date,
        source: source,
        macId: macId?.mac,
        rssi: rssi,
        version: version,
        temperature: temperature.map { Temperature(value: $0, unit: .celsius) },
        humidity: humidity.map {
            Humidity(
                value: $0,
                unit: .relative(temperature: Temperature(value: temperature ?? 20, unit: .celsius))
            )
        },
        pressure: pressure.map { Pressure(value: $0, unit: .hectopascals) },
        acceleration: acceleration,
        voltage: voltage.map { Voltage(value: $0, unit: .volts) },
        movementCounter: movementCounter,
        measurementSequenceNumber: measurementSequenceNumber,
        txPower: nil,
        pm1: pm1,
        pm25: pm25,
        pm4: pm4,
        pm10: pm10,
        co2: co2,
        voc: voc,
        nox: nox,
        luminance: luminance,
        dbaInstant: dbaInstant,
        dbaAvg: dbaAvg,
        dbaPeak: dbaPeak,
        temperatureOffset: 0,
        humidityOffset: 0,
        pressureOffset: 0
    )
}

func makeImage(
    color: UIColor = .red,
    size: CGSize = CGSize(width: 12, height: 12)
) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, true, 1)
    defer { UIGraphicsEndImageContext() }
    color.setFill()
    UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
    return UIGraphicsGetImageFromCurrentImageContext()!
}

func makeQueuedRequest(
    type: RuuviCloudQueuedRequestType = .sensor,
    uniqueKey: String = "request-1"
) -> RuuviCloudQueuedRequest {
    RuuviCloudQueuedRequestStruct(
        id: 1,
        type: type,
        status: nil,
        uniqueKey: uniqueKey,
        requestDate: Date(),
        successDate: nil,
        attempts: 0,
        requestBodyData: nil,
        additionalData: nil
    )
}

func makeCloudAlertToken(id: Int = 1) -> RuuviCloudPNToken {
    RuuviCloudPNTokenStruct(id: id, lastAccessed: nil, name: "Device")
}

func makeCloudSettings(
    unitTemperature: TemperatureUnit? = .fahrenheit,
    accuracyTemperature: MeasurementAccuracyType? = .one,
    unitHumidity: HumidityUnit? = .dew,
    accuracyHumidity: MeasurementAccuracyType? = .one,
    unitPressure: UnitPressure? = .millimetersOfMercury,
    accuracyPressure: MeasurementAccuracyType? = .one,
    chartShowAllPoints: Bool? = true,
    chartDrawDots: Bool? = true,
    chartShowMinMaxAvg: Bool? = true,
    cloudModeEnabled: Bool? = true,
    dashboardEnabled: Bool? = true,
    dashboardType: DashboardType? = .image,
    dashboardTapActionType: DashboardTapActionType? = .card,
    pushAlertDisabled: Bool? = true,
    emailAlertDisabled: Bool? = true,
    marketingPreference: Bool? = true,
    profileLanguageCode: String? = "fi",
    dashboardSensorOrder: String? = "[\"mac-1\",\"mac-2\"]"
) -> RuuviCloudSettings {
    CloudSettingsStub(
        unitTemperature: unitTemperature,
        accuracyTemperature: accuracyTemperature,
        unitHumidity: unitHumidity,
        accuracyHumidity: accuracyHumidity,
        unitPressure: unitPressure,
        accuracyPressure: accuracyPressure,
        chartShowAllPoints: chartShowAllPoints,
        chartDrawDots: chartDrawDots,
        chartViewPeriod: nil,
        chartShowMinMaxAvg: chartShowMinMaxAvg,
        cloudModeEnabled: cloudModeEnabled,
        dashboardEnabled: dashboardEnabled,
        dashboardType: dashboardType,
        dashboardTapActionType: dashboardTapActionType,
        pushAlertDisabled: pushAlertDisabled,
        emailAlertDisabled: emailAlertDisabled,
        marketingPreference: marketingPreference,
        profileLanguageCode: profileLanguageCode,
        dashboardSensorOrder: dashboardSensorOrder
    )
}

func waitUntil(
    timeout: TimeInterval = 1,
    interval: UInt64 = 20_000_000,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: @escaping @Sendable () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return
        }
        try? await Task.sleep(nanoseconds: interval)
    }
    XCTFail("Timed out waiting for condition", file: file, line: line)
}

struct CloudSettingsStub: RuuviCloudSettings {
    var unitTemperature: TemperatureUnit?
    var accuracyTemperature: MeasurementAccuracyType?
    var unitHumidity: HumidityUnit?
    var accuracyHumidity: MeasurementAccuracyType?
    var unitPressure: UnitPressure?
    var accuracyPressure: MeasurementAccuracyType?
    var chartShowAllPoints: Bool?
    var chartDrawDots: Bool?
    var chartViewPeriod: Int?
    var chartShowMinMaxAvg: Bool?
    var cloudModeEnabled: Bool?
    var dashboardEnabled: Bool?
    var dashboardType: DashboardType?
    var dashboardTapActionType: DashboardTapActionType?
    var pushAlertDisabled: Bool?
    var emailAlertDisabled: Bool?
    var marketingPreference: Bool?
    var profileLanguageCode: String?
    var dashboardSensorOrder: String?
}

final class CloudSpy: RuuviCloud {
    private let lock = NSLock()

    struct RegisteredTokenCall {
        let token: String
        let type: String
        let name: String?
        let data: String?
        let params: [String: String]?
    }

    struct UploadCall {
        let data: Data
        let mimeType: MimeType
        let macId: String
    }

    struct SensorSettingsUpdateCall {
        let sensorId: String
        let types: [String]
        let values: [String]
        let timestamp: Int?
    }

    struct OffsetUpdateCall {
        let sensorId: String
        let temperatureOffset: Double?
        let humidityOffset: Double?
        let pressureOffset: Double?
    }

    struct AlertCall {
        let type: RuuviCloudAlertType
        let settingType: RuuviCloudAlertSettingType
        let isEnabled: Bool
        let min: Double?
        let max: Double?
        let counter: Int?
        let delay: Int?
        let description: String?
        let macId: String
    }

    var requestCodeResult: String?
    var validateCodeResult = ValidateCodeResponse(email: "owner@example.com", apiKey: "key")
    var deleteAccountResult = true
    var registerPNTokenResult = 1
    var unregisterPNTokenResult = true
    var listPNTokensResult: [RuuviCloudPNToken] = []
    var loadSensorsResult: [AnyCloudSensor] = []
    var loadSensorsDenseResult: [RuuviCloudSensorDense] = []
    var loadRecordsResult: [AnyRuuviTagSensorRecord] = []
    var onLoadRecords: (() async -> Void)?
    var claimResult: MACIdentifier?
    var contestResult: MACIdentifier?
    var unclaimResult: MACIdentifier = "AA:BB:CC:11:22:33".mac
    var shareResult = ShareSensorResponse(macId: "AA:BB:CC:11:22:33".mac, invited: true)
    var unshareResult: MACIdentifier = "AA:BB:CC:11:22:33".mac
    var loadSharedResult: Set<AnyShareableSensor> = []
    var checkOwnerResult: (String?, String?) = ("owner@example.com", "AA:BB:CC:11:22:33")
    var updatedSensorResult: AnyRuuviTagSensor?
    var uploadedImageURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cloud.jpg")
    var getCloudSettingsResult: RuuviCloudSettings?
    var updateSensorSettingsResult: AnyRuuviTagSensor?
    var updatedOffsetsResult: AnyRuuviTagSensor?
    var loadAlertsResult: [RuuviCloudSensorAlerts] = []
    var executeQueuedRequestResult = true

    var requestCodeError: Error?
    var validateCodeError: Error?
    var registerPNTokenError: Error?
    var unregisterPNTokenError: Error?
    var listPNTokensError: Error?
    var claimError: Error?
    var contestError: Error?
    var unclaimError: Error?
    var shareError: Error?
    var unshareError: Error?
    var loadSharedError: Error?
    var checkOwnerError: Error?
    var updateNameError: Error?
    var uploadError: Error?
    var getCloudSettingsError: Error?
    var updateSensorSettingsError: Error?
    var updateOffsetsError: Error?
    var loadSensorsDenseError: Error?
    var loadRecordsError: Error?
    var executeQueuedRequestError: Error?
    var setAlertError: Error?
    var resetImageError: Error?

    var requestedCodes: [String] = []
    var registeredPNTokens: [RegisteredTokenCall] = []
    var unregisteredTokens: [(String?, Int?)] = []
    var claimCalls: [(String, String)] = []
    var contestCalls: [(String, String)] = []
    var unclaimCalls: [(String, Bool)] = []
    var shareCalls: [(String, String)] = []
    var unshareCalls: [(String, String?)] = []
    var updateNameCalls: [(String, String)] = []
    var uploadCalls: [UploadCall] = []
    var resetImageCalls: [String] = []
    var updateSensorSettingsCalls: [SensorSettingsUpdateCall] = []
    private var _updateOffsetCalls: [OffsetUpdateCall] = []
    var updateOffsetCalls: [OffsetUpdateCall] {
        get { withLock { _updateOffsetCalls } }
        set { withLock { _updateOffsetCalls = newValue } }
    }
    var onUpdateOffset: ((OffsetUpdateCall) -> Void)?
    var setAlertCalls: [AlertCall] = []
    var executedRequests: [String] = []
    var setTemperatureUnits: [TemperatureUnit] = []
    var setTemperatureAccuracies: [MeasurementAccuracyType] = []
    var setHumidityUnits: [HumidityUnit] = []
    var setHumidityAccuracies: [MeasurementAccuracyType] = []
    var setPressureUnits: [UnitPressure] = []
    var setPressureAccuracies: [MeasurementAccuracyType] = []
    var setShowAllDataValues: [Bool] = []
    var setDrawDotsValues: [Bool] = []
    var setChartDurationValues: [Int] = []
    var setShowMinMaxAvgValues: [Bool] = []
    var setCloudModeValues: [Bool] = []
    var setDashboardValues: [Bool] = []
    var setDashboardTypeValues: [DashboardType] = []
    var setDashboardTapActionTypeValues: [DashboardTapActionType] = []
    var setDisableEmailAlertValues: [Bool] = []
    var setDisablePushAlertValues: [Bool] = []
    var setMarketingPreferenceValues: [Bool] = []
    var setProfileLanguageCodeValues: [String] = []
    var setDashboardSensorOrderValues: [[String]] = []
    var setMarketingPreferenceError: Error?

    var uploadProgressUpdates: [Double] = []

    func requestCode(email: String) async throws -> String? {
        requestedCodes.append(email)
        if let requestCodeError { throw requestCodeError }
        return requestCodeResult
    }

    func validateCode(code: String) async throws -> ValidateCodeResponse {
        if let validateCodeError { throw validateCodeError }
        return validateCodeResult
    }

    func deleteAccount(email: String) async throws -> Bool {
        deleteAccountResult
    }

    func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws -> Int {
        registeredPNTokens.append(
            RegisteredTokenCall(token: token, type: type, name: name, data: data, params: params)
        )
        if let registerPNTokenError { throw registerPNTokenError }
        return registerPNTokenResult
    }

    func unregisterPNToken(token: String?, tokenId: Int?) async throws -> Bool {
        unregisteredTokens.append((token, tokenId))
        if let unregisterPNTokenError { throw unregisterPNTokenError }
        return unregisterPNTokenResult
    }

    func listPNTokens() async throws -> [RuuviCloudPNToken] {
        if let listPNTokensError { throw listPNTokensError }
        return listPNTokensResult
    }

    func loadSensors() async throws -> [AnyCloudSensor] {
        loadSensorsResult
    }

    func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) async throws -> [RuuviCloudSensorDense] {
        if let loadSensorsDenseError { throw loadSensorsDenseError }
        return loadSensorsDenseResult
    }

    func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws -> [AnyRuuviTagSensorRecord] {
        if let onLoadRecords {
            await onLoadRecords()
        }
        if let loadRecordsError { throw loadRecordsError }
        return loadRecordsResult
    }

    func claim(name: String, macId: MACIdentifier) async throws -> MACIdentifier? {
        claimCalls.append((name, macId.value))
        if let claimError { throw claimError }
        return claimResult
    }

    func contest(macId: MACIdentifier, secret: String) async throws -> MACIdentifier? {
        contestCalls.append((macId.value, secret))
        if let contestError { throw contestError }
        return contestResult
    }

    func unclaim(macId: MACIdentifier, removeCloudHistory: Bool) async throws -> MACIdentifier {
        unclaimCalls.append((macId.value, removeCloudHistory))
        if let unclaimError { throw unclaimError }
        return unclaimResult
    }

    func share(macId: MACIdentifier, with email: String) async throws -> ShareSensorResponse {
        shareCalls.append((macId.value, email))
        if let shareError { throw shareError }
        return shareResult
    }

    func unshare(macId: MACIdentifier, with email: String?) async throws -> MACIdentifier {
        unshareCalls.append((macId.value, email))
        if let unshareError { throw unshareError }
        return unshareResult
    }

    func loadShared(for sensor: RuuviTagSensor) async throws -> Set<AnyShareableSensor> {
        if let loadSharedError { throw loadSharedError }
        return loadSharedResult
    }

    func checkOwner(macId: MACIdentifier) async throws -> (String?, String?) {
        if let checkOwnerError { throw checkOwnerError }
        return checkOwnerResult
    }

    func update(name: String, for sensor: RuuviTagSensor) async throws -> AnyRuuviTagSensor {
        updateNameCalls.append((sensor.id, name))
        if let updateNameError { throw updateNameError }
        return updatedSensorResult ?? sensor.with(name: name).any
    }

    func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws -> URL {
        uploadCalls.append(UploadCall(data: imageData, mimeType: mimeType, macId: macId.value))
        progress?(macId, 0.25)
        progress?(macId, 1.0)
        uploadProgressUpdates.append(contentsOf: [0.25, 1.0])
        if let uploadError { throw uploadError }
        return uploadedImageURL
    }

    func resetImage(for macId: MACIdentifier) async throws {
        resetImageCalls.append(macId.value)
        if let resetImageError { throw resetImageError }
    }

    func getCloudSettings() async throws -> RuuviCloudSettings? {
        if let getCloudSettingsError { throw getCloudSettingsError }
        return getCloudSettingsResult
    }

    func set(temperatureUnit: TemperatureUnit) async throws -> TemperatureUnit {
        setTemperatureUnits.append(temperatureUnit)
        return temperatureUnit
    }

    func set(temperatureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        setTemperatureAccuracies.append(temperatureAccuracy)
        return temperatureAccuracy
    }

    func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit {
        setHumidityUnits.append(humidityUnit)
        return humidityUnit
    }

    func set(humidityAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        setHumidityAccuracies.append(humidityAccuracy)
        return humidityAccuracy
    }

    func set(pressureUnit: UnitPressure) async throws -> UnitPressure {
        setPressureUnits.append(pressureUnit)
        return pressureUnit
    }

    func set(pressureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        setPressureAccuracies.append(pressureAccuracy)
        return pressureAccuracy
    }

    func set(showAllData: Bool) async throws -> Bool {
        setShowAllDataValues.append(showAllData)
        return showAllData
    }

    func set(drawDots: Bool) async throws -> Bool {
        setDrawDotsValues.append(drawDots)
        return drawDots
    }

    func set(chartDuration: Int) async throws -> Int {
        setChartDurationValues.append(chartDuration)
        return chartDuration
    }

    func set(showMinMaxAvg: Bool) async throws -> Bool {
        setShowMinMaxAvgValues.append(showMinMaxAvg)
        return showMinMaxAvg
    }

    func set(cloudMode: Bool) async throws -> Bool {
        setCloudModeValues.append(cloudMode)
        return cloudMode
    }

    func set(dashboard: Bool) async throws -> Bool {
        setDashboardValues.append(dashboard)
        return dashboard
    }

    func set(dashboardType: DashboardType) async throws -> DashboardType {
        setDashboardTypeValues.append(dashboardType)
        return dashboardType
    }

    func set(dashboardTapActionType: DashboardTapActionType) async throws -> DashboardTapActionType {
        setDashboardTapActionTypeValues.append(dashboardTapActionType)
        return dashboardTapActionType
    }

    func set(disableEmailAlert: Bool) async throws -> Bool {
        setDisableEmailAlertValues.append(disableEmailAlert)
        return disableEmailAlert
    }

    func set(disablePushAlert: Bool) async throws -> Bool {
        setDisablePushAlertValues.append(disablePushAlert)
        return disablePushAlert
    }

    func set(marketingPreference: Bool) async throws -> Bool {
        setMarketingPreferenceValues.append(marketingPreference)
        if let setMarketingPreferenceError { throw setMarketingPreferenceError }
        return marketingPreference
    }

    func set(profileLanguageCode: String) async throws -> String {
        setProfileLanguageCodeValues.append(profileLanguageCode)
        return profileLanguageCode
    }

    func set(dashboardSensorOrder: [String]) async throws -> [String] {
        setDashboardSensorOrderValues.append(dashboardSensorOrder)
        return dashboardSensorOrder
    }

    func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws -> AnyRuuviTagSensor {
        updateSensorSettingsCalls.append(
            SensorSettingsUpdateCall(sensorId: sensor.id, types: types, values: values, timestamp: timestamp)
        )
        if let updateSensorSettingsError { throw updateSensorSettingsError }
        return updateSensorSettingsResult ?? sensor.any
    }

    func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor {
        let call = OffsetUpdateCall(
            sensorId: sensor.id,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset
        )
        let callback = withLock {
            _updateOffsetCalls.append(call)
            return onUpdateOffset
        }
        callback?(call)
        if let updateOffsetsError { throw updateOffsetsError }
        return updatedOffsetsResult ?? sensor.any
    }

    func setAlert(
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
        setAlertCalls.append(
            AlertCall(
                type: type,
                settingType: settingType,
                isEnabled: isEnabled,
                min: min,
                max: max,
                counter: counter,
                delay: delay,
                description: description,
                macId: macId.value
            )
        )
        if let setAlertError { throw setAlertError }
    }

    func loadAlerts() async throws -> [RuuviCloudSensorAlerts] {
        loadAlertsResult
    }

    func executeQueuedRequest(from request: RuuviCloudQueuedRequest) async throws -> Bool {
        executedRequests.append(request.uniqueKey ?? "")
        if let executeQueuedRequestError { throw executeQueuedRequestError }
        return executeQueuedRequestResult
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

final class PoolSpy: RuuviPool {
    struct OffsetCorrectionCall {
        let type: OffsetCorrectionType
        let value: Double?
        let sensorId: String
        let record: RuuviTagSensorRecord?
    }

    struct DisplaySettingsCall {
        let sensorId: String
        let displayOrder: [String]?
        let defaultDisplayOrder: Bool?
        let displayOrderLastUpdated: Date?
        let defaultDisplayOrderLastUpdated: Date?
    }

    struct DescriptionCall {
        let sensorId: String
        let description: String?
        let descriptionLastUpdated: Date?
    }

    var createSensorError: Error?
    var updateSensorError: Error?
    var deleteSensorError: Error?
    var createRecordError: Error?
    var createRecordsError: Error?
    var createLastError: Error?
    var deleteAllRecordsError: Error?
    var deleteLastError: Error?
    var updateOffsetCorrectionError: Error?
    var updateDisplaySettingsError: Error?
    var updateDescriptionError: Error?
    var readSensorSettingsError: Error?
    var deleteQueuedRequestError: Error?
    var deleteQueuedRequestsError: Error?

    var createdSensors: [AnyRuuviTagSensor] = []
    var updatedSensors: [AnyRuuviTagSensor] = []
    var deletedSensors: [AnyRuuviTagSensor] = []
    var deletedSensorSettings: [AnyRuuviTagSensor] = []
    var createdRecord: RuuviTagSensorRecord?
    var createdRecords: [RuuviTagSensorRecord] = []
    var createdLastRecord: RuuviTagSensorRecord?
    var updatedLastRecord: RuuviTagSensorRecord?
    var deletedLastIDs: [String] = []
    var deletedAllRecordIDs: [String] = []
    var offsetCorrectionCalls: [OffsetCorrectionCall] = []
    var displaySettingsCalls: [DisplaySettingsCall] = []
    var descriptionCalls: [DescriptionCall] = []
    var createdQueuedRequests: [RuuviCloudQueuedRequest] = []
    var deletedQueuedRequests: [RuuviCloudQueuedRequest] = []
    var deleteQueuedRequestsCallCount = 0
    var savedSubscriptions: [CloudSensorSubscription] = []

    var offsetSettingsResult: SensorSettings = SensorSettingsStruct(
        luid: "luid-1".luid,
        macId: "AA:BB:CC:11:22:33".mac,
        temperatureOffset: 0,
        humidityOffset: 0,
        pressureOffset: 0
    )
    var displaySettingsResult: SensorSettings = SensorSettingsStruct(
        luid: "luid-1".luid,
        macId: "AA:BB:CC:11:22:33".mac,
        temperatureOffset: nil,
        humidityOffset: nil,
        pressureOffset: nil,
        displayOrder: ["temperature"],
        defaultDisplayOrder: true
    )
    var descriptionSettingsResult: SensorSettings = SensorSettingsStruct(
        luid: "luid-1".luid,
        macId: "AA:BB:CC:11:22:33".mac,
        temperatureOffset: nil,
        humidityOffset: nil,
        pressureOffset: nil,
        description: "Description"
    )
    var readSensorSettingsResult: SensorSettings?

    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        if let createSensorError { throw createSensorError }
        createdSensors.append(ruuviTag.any)
        return true
    }

    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        if let updateSensorError { throw updateSensorError }
        updatedSensors.append(ruuviTag.any)
        return true
    }

    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        if let deleteSensorError { throw deleteSensorError }
        deletedSensors.append(ruuviTag.any)
        return true
    }

    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        deletedSensorSettings.append(ruuviTag.any)
        return true
    }

    func create(_ record: RuuviTagSensorRecord) async throws -> Bool {
        if let createRecordError { throw createRecordError }
        createdRecord = record
        return true
    }

    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        if let createLastError { throw createLastError }
        createdLastRecord = record
        return true
    }

    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        updatedLastRecord = record
        return true
    }

    func deleteLast(_ ruuviTagId: String) async throws -> Bool {
        if let deleteLastError { throw deleteLastError }
        deletedLastIDs.append(ruuviTagId)
        return true
    }

    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool {
        if let createRecordsError { throw createRecordsError }
        createdRecords = records
        return true
    }

    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool {
        if let deleteAllRecordsError { throw deleteAllRecordsError }
        deletedAllRecordIDs.append(ruuviTagId)
        return true
    }

    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool {
        deletedAllRecordIDs.append(ruuviTagId)
        return true
    }

    func cleanupDBSpace() async throws -> Bool {
        true
    }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        if let updateOffsetCorrectionError { throw updateOffsetCorrectionError }
        offsetCorrectionCalls.append(
            OffsetCorrectionCall(type: type, value: value, sensorId: ruuviTag.id, record: record)
        )
        return offsetSettingsResult
    }

    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) async throws -> SensorSettings {
        if let updateDisplaySettingsError { throw updateDisplaySettingsError }
        displaySettingsCalls.append(
            DisplaySettingsCall(
                sensorId: ruuviTag.id,
                displayOrder: displayOrder,
                defaultDisplayOrder: defaultDisplayOrder,
                displayOrderLastUpdated: displayOrderLastUpdated,
                defaultDisplayOrderLastUpdated: defaultDisplayOrderLastUpdated
            )
        )
        return displaySettingsResult
    }

    func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws -> SensorSettings {
        if let updateDescriptionError { throw updateDescriptionError }
        descriptionCalls.append(
            DescriptionCall(
                sensorId: ruuviTag.id,
                description: description,
                descriptionLastUpdated: descriptionLastUpdated
            )
        )
        return descriptionSettingsResult
    }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        if let readSensorSettingsError { throw readSensorSettingsError }
        return readSensorSettingsResult
    }

    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool {
        createdQueuedRequests.append(request)
        return true
    }

    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool {
        if let deleteQueuedRequestError { throw deleteQueuedRequestError }
        deletedQueuedRequests.append(request)
        return true
    }

    func deleteQueuedRequests() async throws -> Bool {
        if let deleteQueuedRequestsError { throw deleteQueuedRequestsError }
        deleteQueuedRequestsCallCount += 1
        return true
    }

    func save(subscription: CloudSensorSubscription) async throws -> CloudSensorSubscription {
        savedSubscriptions.append(subscription)
        return subscription
    }

    func readSensorSubscriptionSettings(_ ruuviTag: RuuviTagSensor) async throws -> CloudSensorSubscription? {
        nil
    }
}

final class StorageSpy: RuuviStorage {
    var readOneResult: AnyRuuviTagSensor = makeSensor().any
    var readAllResult: [AnyRuuviTagSensor] = []
    var readAllAfterResult: [RuuviTagSensorRecord] = []
    var readLastResult: RuuviTagSensorRecord?
    var readLatestResult: RuuviTagSensorRecord?
    var readLastResults: [String: RuuviTagSensorRecord?] = [:]
    var readLatestResults: [String: RuuviTagSensorRecord?] = [:]
    var readSensorSettingsResult: SensorSettings?
    var readQueuedRequestsResult: [RuuviCloudQueuedRequest] = []

    var readAllError: Error?
    var readAllAfterError: Error?
    var readLastError: Error?
    var readLatestError: Error?
    var readQueuedRequestsError: Error?
    var readSensorSettingsError: Error?

    func read(_ id: String, after date: Date, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] {
        []
    }

    func readDownsampled(
        _ id: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws -> [RuuviTagSensorRecord] {
        []
    }

    func readOne(_ id: String) async throws -> AnyRuuviTagSensor {
        readOneResult
    }

    func readAll(_ id: String) async throws -> [RuuviTagSensorRecord] {
        []
    }

    func readAll(_ id: String, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] {
        []
    }

    func readAll(_ id: String, after date: Date) async throws -> [RuuviTagSensorRecord] {
        if let readAllAfterError { throw readAllAfterError }
        return readAllAfterResult
    }

    func readAll() async throws -> [AnyRuuviTagSensor] {
        if let readAllError { throw readAllError }
        return readAllResult
    }

    func readLast(_ id: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] {
        []
    }

    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        if let readLastError { throw readLastError }
        if let value = readLastResults[ruuviTag.id] {
            return value
        }
        return readLastResult
    }

    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        if let readLatestError { throw readLatestError }
        if let value = readLatestResults[ruuviTag.id] {
            return value
        }
        return readLatestResult
    }

    func getStoredTagsCount() async throws -> Int { 0 }
    func getClaimedTagsCount() async throws -> Int { 0 }
    func getOfflineTagsCount() async throws -> Int { 0 }
    func getStoredMeasurementsCount() async throws -> Int { 0 }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        if let readSensorSettingsError { throw readSensorSettingsError }
        return readSensorSettingsResult
    }

    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] {
        if let readQueuedRequestsError { throw readQueuedRequestsError }
        return readQueuedRequestsResult
    }

    func readQueuedRequests(for key: String) async throws -> [RuuviCloudQueuedRequest] {
        readQueuedRequestsResult.filter { $0.uniqueKey == key }
    }

    func readQueuedRequests(for type: RuuviCloudQueuedRequestType) async throws -> [RuuviCloudQueuedRequest] {
        readQueuedRequestsResult.filter { $0.type == type }
    }
}

final class RepositorySpy: RuuviRepository {
    var createRecordError: Error?
    var createRecordsError: Error?
    var createdRecord: RuuviTagSensorRecord?
    var createdRecords: [RuuviTagSensorRecord] = []

    func create(
        record: RuuviTagSensorRecord,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensorRecord {
        if let createRecordError { throw createRecordError }
        createdRecord = record
        return record.any
    }

    func create(
        records: [RuuviTagSensorRecord],
        for sensor: RuuviTagSensor
    ) async throws -> [AnyRuuviTagSensorRecord] {
        if let createRecordsError { throw createRecordsError }
        createdRecords = records
        return records.map(\.any)
    }
}

final class LocalImagesSpy: RuuviLocalImages {
    struct CustomBackgroundCall {
        let identifier: String
        let compressionQuality: CGFloat
        let size: CGSize
    }

    var generatedBackgrounds: [String: UIImage] = [:]
    var backgrounds: [String: UIImage] = [:]
    var customBackgrounds: [String: UIImage] = [:]
    var uploadProgress: [String: Double] = [:]
    var deletedCustomBackgroundIDs: [String] = []
    var setPictureIsCachedIDs: [String] = []
    var removedPictureCacheIDs: [String] = []
    var setBackgroundCalls: [(Int, String)] = []
    var setCustomBackgroundCalls: [CustomBackgroundCall] = []
    var setCustomBackgroundURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("local.jpg")
    var nextDefaultBackgroundImage = makeImage(color: .green)
    var setNextDefaultBackgroundShouldFail = false

    func getOrGenerateBackground(for identifier: Identifier, ruuviDeviceType: RuuviDeviceType) -> UIImage? {
        generatedBackgrounds[identifier.value]
    }

    func getBackground(for identifier: Identifier) -> UIImage? {
        backgrounds[identifier.value]
    }

    func setBackground(_ id: Int, for identifier: Identifier) {
        setBackgroundCalls.append((id, identifier.value))
    }

    func setNextDefaultBackground(for identifier: Identifier) -> UIImage? {
        if setNextDefaultBackgroundShouldFail {
            return nil
        }
        return nextDefaultBackgroundImage
    }

    func getCustomBackground(for identifier: Identifier) -> UIImage? {
        customBackgrounds[identifier.value]
    }

    func setCustomBackground(
        image: UIImage,
        compressionQuality: CGFloat,
        for identifier: Identifier
    ) async throws -> URL {
        customBackgrounds[identifier.value] = image
        setCustomBackgroundCalls.append(
            CustomBackgroundCall(identifier: identifier.value, compressionQuality: compressionQuality, size: image.size)
        )
        return setCustomBackgroundURL
    }

    func deleteCustomBackground(for uuid: Identifier) {
        deletedCustomBackgroundIDs.append(uuid.value)
        customBackgrounds.removeValue(forKey: uuid.value)
    }

    func backgroundUploadProgress(for identifier: Identifier) -> Double? {
        uploadProgress[identifier.value]
    }

    func setBackgroundUploadProgress(percentage: Double, for identifier: Identifier) {
        uploadProgress[identifier.value] = percentage
    }

    func deleteBackgroundUploadProgress(for identifier: Identifier) {
        uploadProgress.removeValue(forKey: identifier.value)
    }

    func isPictureCached(for cloudSensor: CloudSensor) -> Bool {
        setPictureIsCachedIDs.contains(cloudSensor.id)
    }

    func setPictureIsCached(for cloudSensor: CloudSensor) {
        setPictureIsCachedIDs.append(cloudSensor.id)
    }

    func setPictureRemovedFromCache(for ruuviTag: RuuviTagSensor) {
        removedPictureCacheIDs.append(ruuviTag.id)
    }
}

final class CoreImageSpy: RuuviCoreImage {
    var croppedImage = makeImage(color: .blue, size: CGSize(width: 4, height: 4))
    var lastCroppedImage: UIImage?
    var lastMaxSize: CGSize?

    func cropped(image: UIImage, to maxSize: CGSize) -> UIImage {
        lastCroppedImage = image
        lastMaxSize = maxSize
        return croppedImage
    }
}

final class PNManagerSpy: RuuviCorePN {
    var pnTokenData: Data?
    var fcmToken: String?
    var fcmTokenId: Int?
    var fcmTokenLastRefreshed: Date?
    var registerForRemoteNotificationsCallCount = 0
    var authorizationStatus: PNAuthorizationStatus = .authorized

    func registerForRemoteNotifications() {
        registerForRemoteNotificationsCallCount += 1
    }

    func getRemoteNotificationsAuthorizationStatus(completion: @escaping (PNAuthorizationStatus) -> Void) {
        completion(authorizationStatus)
    }
}

final class UserSpy: RuuviUser {
    var apiKey: String?
    var email: String?
    var isAuthorized: Bool = false
    var loginAPIKeys: [String] = []
    var logoutCallCount = 0

    func login(apiKey: String) {
        loginAPIKeys.append(apiKey)
        self.apiKey = apiKey
        isAuthorized = true
    }

    func logout() {
        logoutCallCount += 1
        apiKey = nil
        isAuthorized = false
    }
}

final class SensorPropertiesSpy: RuuviServiceSensorProperties {
    var setNameCalls: [(String, String)] = []
    var setImageCalls: [(sensorID: String, progressWasProvided: Bool, maxSize: CGSize, compressionQuality: CGFloat)] = []
    var removedImageSensorIDs: [String] = []
    var getImageResult = makeImage(color: .orange)
    var getImageError: Error?
    var updateDisplaySettingsCalls: [(String, [String]?, Bool)] = []
    var updateDescriptionCalls: [(String, String?)] = []

    func set(name: String, for sensor: RuuviTagSensor) async throws -> AnyRuuviTagSensor {
        setNameCalls.append((sensor.id, name))
        return sensor.with(name: name).any
    }

    func set(
        image: UIImage,
        for sensor: RuuviTagSensor,
        progress: ((MACIdentifier, Double) -> Void)?,
        maxSize: CGSize,
        compressionQuality: CGFloat
    ) async throws -> URL {
        setImageCalls.append(
            (
                sensorID: sensor.id,
                progressWasProvided: progress != nil,
                maxSize: maxSize,
                compressionQuality: compressionQuality
            )
        )
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sensor.jpg")
    }

    func setNextDefaultBackground(for sensor: RuuviTagSensor) async throws -> UIImage {
        makeImage(color: .purple)
    }

    func getImage(for sensor: RuuviTagSensor) async throws -> UIImage {
        if let getImageError { throw getImageError }
        return getImageResult
    }

    func removeImage(for sensor: RuuviTagSensor) {
        removedImageSensorIDs.append(sensor.id)
    }

    func updateDisplaySettings(
        for sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool
    ) async throws -> SensorSettings {
        updateDisplaySettingsCalls.append((sensor.id, displayOrder, defaultDisplayOrder))
        return SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            displayOrder: displayOrder,
            defaultDisplayOrder: defaultDisplayOrder
        )
    }

    func updateDescription(for sensor: RuuviTagSensor, description: String?) async throws -> SensorSettings {
        updateDescriptionCalls.append((sensor.id, description))
        return SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            description: description
        )
    }
}

struct CloudAlertStub: RuuviCloudAlert {
    var type: RuuviCloudAlertType?
    var enabled: Bool?
    var min: Double?
    var max: Double?
    var counter: Int?
    var delay: Int?
    var description: String?
    var triggered: Bool?
    var triggeredAt: String?
    var lastUpdated: Date?
}

struct CloudSensorAlertsStub: RuuviCloudSensorAlerts {
    var sensor: String?
    var alerts: [RuuviCloudAlert]?
}

final class MeasurementListenerSpy: RuuviServiceMeasurementDelegate {
    private(set) var updateCallCount = 0

    func measurementServiceDidUpdateUnit() {
        updateCallCount += 1
    }
}
