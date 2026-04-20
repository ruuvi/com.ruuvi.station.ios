@testable import RuuviLocal
@testable import RuuviService
import Humidity
import RuuviCloud
import RuuviOntology
import XCTest

final class RuuviServiceFoundationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetTestUserDefaults()
    }

    func testAppSettingsTemperatureUnitUpdatesLocalSettingsAndCloud() async throws {
        let cloud = CloudSpy()
        let settings = makeSettings()
        let sut = RuuviServiceAppSettingsImpl(cloud: cloud, localSettings: settings)

        let result = try await sut.set(temperatureUnit: .fahrenheit)

        XCTAssertEqual(result, .fahrenheit)
        XCTAssertEqual(settings.temperatureUnit, .fahrenheit)
        XCTAssertEqual(cloud.setTemperatureUnits, [.fahrenheit])
    }

    func testAppSettingsPreservesLocalMarketingPreferenceWhenCloudFails() async {
        let cloud = CloudSpy()
        cloud.setMarketingPreferenceError = RuuviCloudError.notAuthorized
        let settings = makeSettings()
        let sut = RuuviServiceAppSettingsImpl(cloud: cloud, localSettings: settings)

        do {
            _ = try await sut.set(marketingPreference: true)
            XCTFail("Expected service error")
        } catch let error as RuuviServiceError {
            guard case let .ruuviCloud(cloudError) = error,
                  case .notAuthorized = cloudError else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(settings.marketingPreference)
    }

    func testAppSettingsForwardsDashboardSensorOrder() async throws {
        let cloud = CloudSpy()
        let sut = RuuviServiceAppSettingsImpl(cloud: cloud, localSettings: makeSettings())

        let result = try await sut.set(dashboardSensorOrder: ["a", "b"])

        XCTAssertEqual(result, ["a", "b"])
        XCTAssertEqual(cloud.setDashboardSensorOrderValues, [["a", "b"]])
    }

    func testMeasurementReturnsEmptyStringForMissingValues() {
        let sut = RuuviServiceMeasurementImpl(
            settings: makeSettings(),
            emptyValueString: "-",
            percentString: "%"
        )

        XCTAssertEqual(sut.string(for: nil as Temperature?, allowSettings: true), "-")
        XCTAssertEqual(sut.string(for: nil as Pressure?, allowSettings: false), "-")
        XCTAssertEqual(sut.string(for: nil as Double?), "")
    }

    func testMeasurementUpdatesUnitsAndDeduplicatesListenerOnSettingsChange() async {
        let settings = makeSettings()
        let sut = RuuviServiceMeasurementImpl(
            settings: settings,
            emptyValueString: "-",
            percentString: "%"
        )
        let listener = MeasurementListenerSpy()

        sut.add(listener)
        sut.add(listener)
        settings.temperatureUnit = .fahrenheit

        await waitUntil {
            sut.units.temperatureUnit == .fahrenheit
        }

        XCTAssertEqual(listener.updateCallCount, 1)
    }

    func testMeasurementRoundsAirQualityAndClassifiesState() {
        let sut = RuuviServiceMeasurementImpl(
            settings: makeSettings(),
            emptyValueString: "-",
            percentString: "%"
        )

        let result = sut.aqi(for: 420, pm25: 0)

        XCTAssertEqual(result.currentScore, 100)
        XCTAssertEqual(result.maxScore, 100)
        guard case .excellent = result.state else {
            return XCTFail("Expected excellent state")
        }
    }

    func testMeasurementConvertsTemperatureOffsetForFahrenheit() {
        let settings = makeSettings()
        settings.temperatureUnit = .fahrenheit
        let sut = RuuviServiceMeasurementImpl(
            settings: settings,
            emptyValueString: "-",
            percentString: "%"
        )

        XCTAssertEqual(sut.temperatureOffsetCorrection(for: 2), 3.6, accuracy: 0.0001)
    }

    func testSensorRecordsClearDeletesRecordsAndResetsSyncDates() async throws {
        let pool = PoolSpy()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let macId = "AA:BB:CC:11:22:33".mac
        let sensor = makeSensor(macId: macId.value)
        let date = Date()
        syncState.setSyncDate(date, for: macId)
        syncState.setSyncDate(date)
        syncState.setGattSyncDate(date, for: macId)
        syncState.setAutoGattSyncAttemptDate(date, for: macId)
        let sut = RuuviServiceSensorRecordsImpl(pool: pool, localSyncState: syncState)

        try await sut.clear(for: sensor)

        XCTAssertEqual(pool.deletedAllRecordIDs, [sensor.id])
        XCTAssertNil(syncState.getSyncDate(for: macId))
        XCTAssertNil(syncState.getSyncDate())
        XCTAssertNil(syncState.getGattSyncDate(for: macId))
        XCTAssertNil(syncState.getAutoGattSyncAttemptDate(for: macId))
    }

    func testCloudNotificationReturnsCurrentTokenIdWhenUserIsUnauthorized() async throws {
        let user = UserSpy()
        user.isAuthorized = false
        let pnManager = PNManagerSpy()
        pnManager.fcmTokenId = 77
        let sut = RuuviServiceCloudNotificationImpl(
            cloud: CloudSpy(),
            pool: PoolSpy(),
            storage: StorageSpy(),
            ruuviUser: user,
            pnManager: pnManager
        )

        let tokenId = try await sut.set(
            token: "token",
            name: "Device",
            data: nil,
            language: .english,
            sound: .systemDefault
        )

        XCTAssertEqual(tokenId, 77)
    }

    func testCloudNotificationRefreshesStaleTokenAndUpdatesManager() async throws {
        let cloud = CloudSpy()
        cloud.registerPNTokenResult = 99
        let user = UserSpy()
        user.isAuthorized = true
        let pnManager = PNManagerSpy()
        pnManager.fcmTokenId = 5
        pnManager.fcmTokenLastRefreshed = Calendar.current.date(byAdding: .day, value: -8, to: Date())
        let sut = RuuviServiceCloudNotificationImpl(
            cloud: cloud,
            pool: PoolSpy(),
            storage: StorageSpy(),
            ruuviUser: user,
            pnManager: pnManager
        )

        let tokenId = try await sut.set(
            token: "fresh-token",
            name: "Phone",
            data: "payload",
            language: .finnish,
            sound: .systemDefault
        )

        XCTAssertEqual(tokenId, 99)
        XCTAssertEqual(cloud.registeredPNTokens.count, 1)
        XCTAssertEqual(pnManager.fcmTokenId, 99)
        XCTAssertEqual(pnManager.fcmToken, "fresh-token")
        XCTAssertNotNil(pnManager.fcmTokenLastRefreshed)
    }

    func testCloudNotificationSkipsRefreshWhenTokenIsFresh() async throws {
        let cloud = CloudSpy()
        let user = UserSpy()
        user.isAuthorized = true
        let pnManager = PNManagerSpy()
        pnManager.fcmTokenId = 42
        pnManager.fcmTokenLastRefreshed = Date()
        let sut = RuuviServiceCloudNotificationImpl(
            cloud: cloud,
            pool: PoolSpy(),
            storage: StorageSpy(),
            ruuviUser: user,
            pnManager: pnManager
        )

        let tokenId = try await sut.set(
            token: "still-valid",
            name: "Phone",
            data: nil,
            language: .english,
            sound: .systemDefault
        )

        XCTAssertEqual(tokenId, 42)
        XCTAssertTrue(cloud.registeredPNTokens.isEmpty)
    }

    func testCloudNotificationSetSoundUsesStoredTokenAndRefreshesManager() async throws {
        let cloud = CloudSpy()
        cloud.registerPNTokenResult = 88
        let user = UserSpy()
        user.isAuthorized = true
        let pnManager = PNManagerSpy()
        pnManager.fcmToken = "existing-token"
        pnManager.fcmTokenId = 10
        let sut = RuuviServiceCloudNotificationImpl(
            cloud: cloud,
            pool: PoolSpy(),
            storage: StorageSpy(),
            ruuviUser: user,
            pnManager: pnManager
        )

        let tokenId = try await sut.set(
            sound: .systemDefault,
            language: .swedish,
            deviceName: "Tablet"
        )

        XCTAssertEqual(tokenId, 88)
        XCTAssertEqual(cloud.registeredPNTokens.first?.token, "existing-token")
        XCTAssertEqual(cloud.registeredPNTokens.first?.name, "Tablet")
        XCTAssertEqual(
            cloud.registeredPNTokens.first?.params?[RuuviCloudPNTokenRegisterRequestParamsKey.language.rawValue],
            "sv"
        )
        XCTAssertEqual(pnManager.fcmTokenId, 88)
        XCTAssertEqual(pnManager.fcmToken, "existing-token")
        XCTAssertNotNil(pnManager.fcmTokenLastRefreshed)
    }

    func testCloudNotificationWrapperMethodsDelegateToCloud() async throws {
        let cloud = CloudSpy()
        cloud.registerPNTokenResult = 23
        cloud.unregisterPNTokenResult = true
        cloud.listPNTokensResult = [makeCloudAlertToken(id: 7)]
        let sut = RuuviServiceCloudNotificationImpl(
            cloud: cloud,
            pool: PoolSpy(),
            storage: StorageSpy(),
            ruuviUser: UserSpy(),
            pnManager: PNManagerSpy()
        )

        let registeredId = try await sut.register(
            token: "raw-token",
            type: "ios",
            name: "Phone",
            data: "payload",
            params: ["language": "en"]
        )
        let unregistered = try await sut.unregister(token: "raw-token", tokenId: 23)
        let tokens = try await sut.listTokens()

        XCTAssertEqual(registeredId, 23)
        XCTAssertEqual(cloud.registeredPNTokens.first?.token, "raw-token")
        XCTAssertEqual(cloud.unregisteredTokens.first?.0, "raw-token")
        XCTAssertEqual(cloud.unregisteredTokens.first?.1, 23)
        XCTAssertTrue(unregistered)
        XCTAssertEqual(tokens.map(\.id), [7])
    }

    func testOffsetCalibrationUpdatesTemperatureAndPressureCloudUnits() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let sensor = makeSensor(isCloud: true)
        let sut = RuuviServiceAppOffsetCalibrationImpl(cloud: cloud, pool: pool)
        let offsetsUpdated = expectation(description: "cloud offsets updated")
        offsetsUpdated.expectedFulfillmentCount = 2
        cloud.onUpdateOffset = { _ in
            offsetsUpdated.fulfill()
        }

        _ = try await sut.set(
            offset: 1.5,
            of: .temperature,
            for: sensor,
            lastOriginalRecord: nil
        )
        _ = try await sut.set(
            offset: 2.25,
            of: .pressure,
            for: sensor,
            lastOriginalRecord: nil
        )

        XCTAssertEqual(pool.offsetCorrectionCalls.map(\.type), [.temperature, .pressure])
        await fulfillment(of: [offsetsUpdated], timeout: 3)
        let temperatureCall = try XCTUnwrap(
            cloud.updateOffsetCalls.first(where: { $0.temperatureOffset != nil })
        )
        let pressureCall = try XCTUnwrap(
            cloud.updateOffsetCalls.first(where: { $0.pressureOffset != nil })
        )
        XCTAssertEqual(temperatureCall.temperatureOffset ?? 0, 1.5, accuracy: 0.0001)
        XCTAssertEqual(pressureCall.pressureOffset ?? 0, 225, accuracy: 0.0001)
    }

    func testOffsetCalibrationLocalSensorUpdatesOnlyPool() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let sensor = makeSensor(isCloud: false)
        let sut = RuuviServiceAppOffsetCalibrationImpl(cloud: cloud, pool: pool)

        _ = try await sut.set(
            offset: 0.5,
            of: .temperature,
            for: sensor,
            lastOriginalRecord: nil
        )

        XCTAssertEqual(pool.offsetCorrectionCalls.first?.value, 0.5)
        XCTAssertTrue(cloud.updateOffsetCalls.isEmpty)
        XCTAssertEqual(pool.updatedSensors.first?.id, sensor.id)
    }

    func testFactoryCreatesExpectedConcreteTypes() {
        let factory = RuuviServiceFactoryImpl()
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let repository = RepositorySpy()
        let user = UserSpy()
        let settings = makeSettings()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let localImages = LocalImagesSpy()
        let properties = SensorPropertiesSpy()
        let coreImage = CoreImageSpy()
        let pnManager = PNManagerSpy()
        let alert = RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: localIDs,
            ruuviLocalSettings: settings
        )
        let appSettings = RuuviServiceAppSettingsImpl(cloud: cloud, localSettings: settings)

        XCTAssertTrue(
            factory.createAppSettings(
                ruuviCloud: cloud,
                ruuviLocalSettings: settings
            ) is RuuviServiceAppSettingsImpl
        )
        XCTAssertTrue(
            factory.createSensorRecords(
                ruuviPool: pool,
                ruuviLocalSyncState: syncState
            ) is RuuviServiceSensorRecordsImpl
        )
        XCTAssertTrue(
            factory.createSensorProperties(
                ruuviPool: pool,
                ruuviCloud: cloud,
                ruuviCoreImage: coreImage,
                ruuviLocalImages: localImages
            ) is RuuviServiceSensorPropertiesImpl
        )
        XCTAssertTrue(
            factory.createOffsetCalibration(
                ruuviCloud: cloud,
                ruuviPool: pool
            ) is RuuviServiceAppOffsetCalibrationImpl
        )
        XCTAssertTrue(
            factory.createAlert(
                ruuviCloud: cloud,
                ruuviLocalIDs: localIDs,
                ruuviLocalSettings: settings
            ) is RuuviServiceAlertImpl
        )
        XCTAssertTrue(
            factory.createCloudNotification(
                ruuviCloud: cloud,
                ruuviPool: pool,
                storage: storage,
                ruuviUser: user,
                pnManager: pnManager
            ) is RuuviServiceCloudNotificationImpl
        )
        XCTAssertTrue(
            factory.createAuth(
                ruuviUser: user,
                pool: pool,
                storage: storage,
                propertiesService: properties,
                localIDs: localIDs,
                localSyncState: syncState,
                alertService: alert,
                settings: settings
            ) is RuuviServiceAuthImpl
        )
        XCTAssertTrue(
            factory.createOwnership(
                ruuviCloud: cloud,
                ruuviPool: pool,
                propertiesService: properties,
                localIDs: localIDs,
                localImages: localImages,
                storage: storage,
                alertService: alert,
                ruuviUser: user,
                localSyncState: syncState,
                settings: settings
            ) is RuuviServiceOwnershipImpl
        )
        XCTAssertTrue(
            factory.createCloudSync(
                ruuviStorage: storage,
                ruuviCloud: cloud,
                ruuviPool: pool,
                ruuviLocalSettings: settings,
                ruuviLocalSyncState: syncState,
                ruuviLocalImages: localImages,
                ruuviRepository: repository,
                ruuviLocalIDs: localIDs,
                ruuviAlertService: alert,
                ruuviAppSettingsService: appSettings
            ) is RuuviServiceCloudSyncImpl
        )
    }

    func testOffsetCalibrationUpdatesPoolAndQueuesCloudHumidityOffsetInPercent() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let sensor = makeSensor(isCloud: true)
        let sut = RuuviServiceAppOffsetCalibrationImpl(cloud: cloud, pool: pool)

        _ = try await sut.set(
            offset: 0.12,
            of: .humidity,
            for: sensor,
            lastOriginalRecord: makeRecord(temperature: 20, humidity: 0.55)
        )

        XCTAssertEqual(pool.offsetCorrectionCalls.first?.type, .humidity)
        XCTAssertEqual(pool.offsetCorrectionCalls.first?.value ?? 0, 0.12, accuracy: 0.0001)
        await waitUntil {
            cloud.updateOffsetCalls.count == 1
        }
        XCTAssertEqual(cloud.updateOffsetCalls.first?.humidityOffset ?? 0, 12, accuracy: 0.0001)
    }

    func testOffsetCalibrationNilOffsetsQueueZeroValuesOnCloud() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let sensor = makeSensor(isCloud: true)
        let sut = RuuviServiceAppOffsetCalibrationImpl(cloud: cloud, pool: pool)

        _ = try await sut.set(offset: nil, of: .temperature, for: sensor, lastOriginalRecord: nil)
        _ = try await sut.set(offset: nil, of: .humidity, for: sensor, lastOriginalRecord: nil)
        _ = try await sut.set(offset: nil, of: .pressure, for: sensor, lastOriginalRecord: nil)

        await waitUntil {
            cloud.updateOffsetCalls.count == 3
        }
        XCTAssertTrue(cloud.updateOffsetCalls.contains { $0.temperatureOffset == 0 })
        XCTAssertTrue(cloud.updateOffsetCalls.contains { $0.humidityOffset == 0 })
        XCTAssertTrue(cloud.updateOffsetCalls.contains { $0.pressureOffset == 0 })
    }

    func testExportCsvSanitizesFileNameAppliesOffsetsAndIncludesDataSource() async throws {
        let settings = makeSettings()
        settings.includeDataSourceInHistoryExport = true
        let sensor = makeSensor(name: "Kitchen/Freezer")
        let storage = StorageSpy()
        storage.readOneResult = sensor.any
        storage.readAllAfterResult = [
            makeRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                date: Date(timeIntervalSince1970: 1_700_000_000),
                source: .advertisement,
                temperature: 20,
                humidity: 0.5,
                pressure: 1000,
                rssi: -70
            )
        ]
        let sut = RuuviServiceExportImpl(
            ruuviStorage: storage,
            measurementService: RuuviServiceMeasurementImpl(
                settings: settings,
                emptyValueString: "-",
                percentString: "%"
            ),
            emptyValueString: "-",
            ruuviLocalSettings: settings
        )
        let offsets = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: 2,
            humidityOffset: 0.1,
            pressureOffset: 5
        )

        let url = try await sut.csvLog(for: sensor.id, version: 5, settings: offsets)
        let text = try String(contentsOf: url)
        let rows = text.split(separator: "\n")

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(url.lastPathComponent.hasPrefix("Kitchen_Freezer_"))
        XCTAssertEqual(rows.count, 2)
        let dataColumns = rows[1].split(separator: ",")
        XCTAssertEqual(dataColumns.last, "advertisement")
        XCTAssertTrue(rows[1].contains("22"))
        XCTAssertTrue(rows[1].contains("60"))
        XCTAssertTrue(rows[1].contains("1005"))
    }

    func testExportCsvIncludesTagSpecificColumnsForMovementVoltageAccelerationAndSequence() async throws {
        let settings = makeSettings()
        let sensor = makeSensor(name: "Workshop/Sensor")
        let storage = StorageSpy()
        storage.readOneResult = sensor.any
        storage.readAllAfterResult = [
            makeRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                date: Date(timeIntervalSince1970: 1_700_001_000),
                source: .log,
                temperature: 20,
                humidity: 0.45,
                pressure: 1001.4,
                voltage: 3.012,
                acceleration: Acceleration(
                    x: AccelerationMeasurement(value: 0.123, unit: .gravity),
                    y: AccelerationMeasurement(value: -0.456, unit: .gravity),
                    z: AccelerationMeasurement(value: 0.789, unit: .gravity)
                ),
                movementCounter: 12,
                measurementSequenceNumber: 321,
                rssi: -55
            ),
            makeRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                date: Date(timeIntervalSince1970: 1_700_001_060),
                source: .log,
                temperature: nil,
                humidity: 0.45,
                pressure: -0.01,
                voltage: 0,
                acceleration: nil,
                movementCounter: nil,
                measurementSequenceNumber: nil,
                rssi: nil
            )
        ]
        let sut = RuuviServiceExportImpl(
            ruuviStorage: storage,
            measurementService: RuuviServiceMeasurementImpl(
                settings: settings,
                emptyValueString: "-",
                percentString: "%"
            ),
            emptyValueString: "-",
            ruuviLocalSettings: settings
        )

        let url = try await sut.csvLog(for: sensor.id, version: 5, settings: nil)
        let text = try String(contentsOf: url)
        let rows = text.split(separator: "\n")
        let columns = rows[1].split(separator: ",")

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(columns.count, 20)
        XCTAssertEqual(columns[13], "12")
        XCTAssertEqual(columns[14], "3.012")
        XCTAssertEqual(columns[15], "0.123")
        XCTAssertEqual(columns[16], "-0.456")
        XCTAssertEqual(columns[17], "0.789")
        XCTAssertEqual(columns[18], "-55")
        XCTAssertEqual(columns[19], "321")
        let emptyTagColumns = Array(rows[2].split(separator: ",").dropFirst())
        XCTAssertEqual(emptyTagColumns, Array(repeating: Substring("-"), count: 19))
    }

    func testExportCsvIncludesAirMeasurementColumnsForEnvironmentalFirmware() async throws {
        let settings = makeSettings()
        let sensor = makeSensor(version: 225, name: "Air/Sensor")
        let storage = StorageSpy()
        storage.readOneResult = sensor.any
        storage.readAllAfterResult = [
            makeRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                date: Date(timeIntervalSince1970: 1_700_002_000),
                source: .advertisement,
                temperature: 20,
                humidity: 0.5,
                pressure: 1000,
                rssi: nil,
                co2: 420,
                pm25: 0,
                pm1: 1,
                pm4: 4,
                pm10: 10,
                voc: 50,
                nox: 40,
                luminance: 123,
                dbaInstant: 60,
                dbaAvg: 55,
                dbaPeak: 65
            ),
            makeRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                date: Date(timeIntervalSince1970: 1_700_002_060),
                source: .advertisement,
                temperature: nil,
                humidity: nil,
                pressure: -0.01,
                rssi: nil,
                co2: nil,
                pm25: nil,
                pm1: nil,
                pm4: nil,
                pm10: nil,
                voc: nil,
                nox: nil,
                luminance: nil,
                dbaInstant: nil,
                dbaAvg: nil,
                dbaPeak: nil
            )
        ]
        let sut = RuuviServiceExportImpl(
            ruuviStorage: storage,
            measurementService: RuuviServiceMeasurementImpl(
                settings: settings,
                emptyValueString: "-",
                percentString: "%"
            ),
            emptyValueString: "-",
            ruuviLocalSettings: settings
        )

        let url = try await sut.csvLog(for: sensor.id, version: 225, settings: nil)
        let text = try String(contentsOf: url)
        let rows = text.split(separator: "\n")
        let columns = rows[1].split(separator: ",")

        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(columns.count, 25)
        XCTAssertEqual(columns[1], "100.0")
        XCTAssertEqual(columns[2], "420")
        XCTAssertEqual(columns[3], "1")
        XCTAssertEqual(columns[4], "0")
        XCTAssertEqual(columns[5], "4")
        XCTAssertEqual(columns[6], "10")
        XCTAssertEqual(columns[7], "50")
        XCTAssertEqual(columns[8], "40")
        XCTAssertEqual(columns[21], "60")
        XCTAssertEqual(columns[22], "55")
        XCTAssertEqual(columns[23], "65")
        XCTAssertEqual(columns[24], "123")
        let emptyAirColumns = Array(rows[2].split(separator: ",").dropFirst())
        XCTAssertEqual(emptyAirColumns, Array(repeating: Substring("-"), count: 24))
    }

    func testExportXlsxCreatesWorkbookWithNonEmptyContents() async throws {
        let settings = makeSettings()
        let sensor = makeSensor(name: "Cellar/Sensor")
        let storage = StorageSpy()
        storage.readOneResult = sensor.any
        storage.readAllAfterResult = [
            makeRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                date: Date(timeIntervalSince1970: 1_700_000_100),
                source: .log,
                temperature: 18,
                humidity: 0.45,
                pressure: 1008
            )
        ]
        let sut = RuuviServiceExportImpl(
            ruuviStorage: storage,
            measurementService: RuuviServiceMeasurementImpl(
                settings: settings,
                emptyValueString: "-",
                percentString: "%"
            ),
            emptyValueString: "-",
            ruuviLocalSettings: settings
        )

        let url = try await sut.xlsxLog(for: sensor.id, version: 5, settings: nil)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? NSNumber

        XCTAssertEqual(url.pathExtension, "xlsx")
        XCTAssertTrue(url.lastPathComponent.hasPrefix("Cellar_Sensor_"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertGreaterThan(fileSize?.intValue ?? 0, 0)
    }

    func testSyncCollisionResolverHonorsToleranceAndBackwardCompatibility() {
        let local = Date(timeIntervalSince1970: 100)
        let withinToleranceCloud = local.addingTimeInterval(0.5)
        let newerCloud = local.addingTimeInterval(2)

        XCTAssertEqual(
            SyncCollisionResolver.resolve(
                localTimestamp: local,
                cloudTimestamp: withinToleranceCloud
            ),
            .noAction
        )
        XCTAssertEqual(
            SyncCollisionResolver.resolve(
                localTimestamp: local,
                cloudTimestamp: newerCloud
            ),
            .updateLocal
        )
        XCTAssertEqual(
            SyncCollisionResolver.resolve(
                localTimestamp: nil,
                cloudTimestamp: newerCloud
            ),
            .updateLocal
        )
        XCTAssertEqual(
            SyncCollisionResolver.resolve(
                localTimestamp: local,
                cloudTimestamp: nil
            ),
            .keepLocalAndQueue
        )
        XCTAssertEqual(
            SyncCollisionResolver.resolve(
                isOwner: true,
                localTimestamp: nil,
                cloudTimestamp: nil
            ),
            .updateLocal
        )
    }

    func testAsyncOperationReportsAsynchronousStateAndFinishesWhenCancelledBeforeStart() {
        let operation = AsyncOperation()

        XCTAssertTrue(operation.isAsynchronous)
        XCTAssertTrue(operation.isReady)
        XCTAssertFalse(operation.isExecuting)
        XCTAssertFalse(operation.isFinished)

        operation.cancel()

        XCTAssertTrue(operation.isFinished)
    }
}
