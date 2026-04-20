@testable import RuuviOntology
import CoreLocation
import GRDB
import Humidity
import XCTest

final class RuuviOntologyModelTests: XCTestCase {
    func testCloudSensorShareableSensorAndDenseWrappersExposeExpectedValues() {
        let cloudSensor = CloudSensorStruct(
            id: "AA:BB:CC:11:22:33",
            serviceUUID: "service",
            name: "",
            isClaimed: false,
            isOwner: false,
            owner: "OWNER@EXAMPLE.COM",
            ownersPlan: "pro",
            picture: URL(string: "https://example.com/picture.jpg"),
            offsetTemperature: 1.5,
            offsetHumidity: 2.5,
            offsetPressure: 3.5,
            isCloudSensor: true,
            canShare: true,
            sharedTo: ["friend@example.com"],
            maxHistoryDays: 365,
            lastUpdated: Date(timeIntervalSince1970: 100)
        )
        let record = makeOntologyRecord(macId: cloudSensor.id, sequence: 42)
        let subscription = SubscriptionStub(macId: cloudSensor.id, subscriptionName: "pro", maxHistoryDays: 365)
        let unidentifiedSubscription = SubscriptionStub(macId: nil, subscriptionName: nil, maxHistoryDays: nil)
        let dense = RuuviCloudSensorDense(
            sensor: cloudSensor,
            record: record,
            alerts: AlertSensorStub(sensor: cloudSensor.id, alerts: []),
            subscription: subscription,
            settings: RuuviCloudSensorSettings(
                displayOrderCodes: ["temperature"],
                defaultDisplayOrder: false,
                description: "Kitchen"
            )
        )
        let anyDense = AnyCloudSensorDense(
            sensor: cloudSensor,
            record: record,
            subscription: subscription
        )
        let anyCloud = cloudSensor.any
        let namedCloudSensor = CloudSensorStruct(
            id: cloudSensor.id,
            serviceUUID: cloudSensor.serviceUUID,
            name: "Kitchen",
            isClaimed: true,
            isOwner: true,
            owner: cloudSensor.owner,
            ownersPlan: cloudSensor.ownersPlan,
            picture: cloudSensor.picture,
            offsetTemperature: cloudSensor.offsetTemperature,
            offsetHumidity: cloudSensor.offsetHumidity,
            offsetPressure: cloudSensor.offsetPressure,
            isCloudSensor: cloudSensor.isCloudSensor,
            canShare: cloudSensor.canShare,
            sharedTo: cloudSensor.sharedTo,
            maxHistoryDays: cloudSensor.maxHistoryDays,
            lastUpdated: cloudSensor.lastUpdated
        )
        let shareable = ShareableSensorStruct(
            id: cloudSensor.id,
            canShare: true,
            sharedTo: ["friend@example.com"]
        )
        let sensorFromCloud = cloudSensor.ruuviTagSensor
        let ownedSensor = cloudSensor.with(email: "owner@example.com")
        let unownedSensor = cloudSensor.with(email: "other@example.com")

        XCTAssertEqual(sensorFromCloud.name, cloudSensor.id)
        XCTAssertEqual(namedCloudSensor.ruuviTagSensor.name, "Kitchen")
        XCTAssertEqual(sensorFromCloud.macId?.value, cloudSensor.id)
        XCTAssertEqual(sensorFromCloud.maxHistoryDays, 365)
        XCTAssertEqual(ownedSensor.owner, "owner@example.com")
        XCTAssertEqual(ownedSensor.isOwner, true)
        XCTAssertEqual(ownedSensor.isClaimed, true)
        XCTAssertEqual(unownedSensor.isOwner, false)
        XCTAssertEqual(unownedSensor.isClaimed, false)
        XCTAssertEqual(anyCloud.name, "")
        XCTAssertEqual(anyCloud.isClaimed, false)
        XCTAssertEqual(anyCloud.isOwner, false)
        XCTAssertEqual(anyCloud.owner, "owner@example.com")
        XCTAssertEqual(anyCloud.ownersPlan, "pro")
        XCTAssertEqual(anyCloud.picture, cloudSensor.picture)
        XCTAssertEqual(anyCloud.offsetTemperature, 1.5)
        XCTAssertEqual(anyCloud.offsetHumidity, 2.5)
        XCTAssertEqual(anyCloud.offsetPressure, 3.5)
        XCTAssertEqual(anyCloud.isCloudSensor, true)
        XCTAssertEqual(anyCloud.canShare, true)
        XCTAssertEqual(anyCloud.sharedTo, ["friend@example.com"])
        XCTAssertEqual(anyCloud.maxHistoryDays, 365)
        XCTAssertEqual(anyCloud.lastUpdated, cloudSensor.lastUpdated)
        XCTAssertEqual(anyCloud.serviceUUID, "service")
        XCTAssertEqual(Set([anyCloud]).count, 1)
        XCTAssertEqual(cloudSensor.any, ownedSensor.any)
        XCTAssertEqual(cloudSensor.any.orderElement, cloudSensor.id)
        XCTAssertEqual(shareable.any.id, cloudSensor.id)
        XCTAssertEqual(shareable.any.sharedTo, ["friend@example.com"])
        XCTAssertEqual(shareable.any.orderElement, cloudSensor.id)
        XCTAssertEqual(Set([shareable.any]).count, 1)
        XCTAssertEqual(dense.settings?.description, "Kitchen")
        XCTAssertEqual(anyDense.id, cloudSensor.id)
        XCTAssertEqual(anyDense.serviceUUID, "service")
        XCTAssertEqual(anyDense.owner, "OWNER@EXAMPLE.COM")
        XCTAssertEqual(anyDense.ownersPlan, "pro")
        XCTAssertEqual(anyDense.maxHistoryDays, 365)
        XCTAssertEqual(anyDense.measurementSequenceNumber, 42)
        XCTAssertEqual(anyDense.temperature?.value, 21.5)
        XCTAssertEqual(anyDense.pm25, 2.2)
        XCTAssertEqual(anyDense.orderElement, cloudSensor.id)
        XCTAssertEqual(anyDense, AnyCloudSensorDense(sensor: ownedSensor, record: record, subscription: subscription))
        XCTAssertEqual(unidentifiedSubscription.id, "")
    }

    func testLocationMeasurementAndRecordMappingExposeExpectedValues() {
        let record = makeOntologyRecord(macId: "AA:BB:CC:11:22:33", sequence: 7)
        let pm25OnlyRecord = makeOntologyRecord(
            macId: "AA:BB:CC:11:22:33",
            sequence: 8,
            co2: nil,
            pm25: 2.2
        )
        let unidentifiedRecord = makeOntologyRecord(
            macId: nil,
            sequence: 9,
            luid: nil,
            co2: nil,
            pm25: nil
        )
        let measurement = record.measurement
        let localMeasurement = RuuviMeasurement(
            luid: "local-measurement".luid,
            macId: nil,
            measurementSequenceNumber: nil,
            date: Date(timeIntervalSince1970: 1),
            rssi: nil,
            temperature: nil,
            humidity: nil,
            pressure: nil,
            co2: nil,
            pm1: nil,
            pm25: nil,
            pm4: nil,
            pm10: nil,
            voc: nil,
            nox: nil,
            luminosity: nil,
            soundInstant: nil,
            soundAvg: nil,
            soundPeak: nil,
            acceleration: nil,
            voltage: nil,
            movementCounter: nil,
            txPower: nil
        )
        var unidentifiedMeasurement = localMeasurement
        unidentifiedMeasurement.luid = nil
        let cityCountry = LocationStub(city: "Helsinki", state: nil, country: "Finland")
        let cityState = LocationStub(city: "Oslo", state: "Oslo", country: "Norway")
        let countryOnly = LocationStub(city: nil, state: nil, country: "Finland")

        XCTAssertEqual(measurement.id, "AA:BB:CC:11:22:33")
        XCTAssertEqual(localMeasurement.id, "local-measurement")
        XCTAssertEqual(unidentifiedMeasurement.id, "")
        XCTAssertEqual(unidentifiedRecord.id, "")
        XCTAssertEqual(unidentifiedRecord.uuid, "")
        XCTAssertEqual(record.any, record.any)
        XCTAssertNotEqual(record.any, unidentifiedRecord.any)
        XCTAssertEqual(measurement.measurementSequenceNumber, 7)
        XCTAssertEqual(measurement.temperature?.value, 21.5)
        XCTAssertEqual(measurement.soundPeak, 62.4)
        XCTAssertTrue(record.hasMeasurement(for: .temperature))
        XCTAssertTrue(record.hasMeasurement(for: .humidity))
        XCTAssertTrue(record.hasMeasurement(for: .pressure))
        XCTAssertTrue(record.hasMeasurement(for: .aqi))
        XCTAssertTrue(pm25OnlyRecord.hasMeasurement(for: .aqi))
        XCTAssertTrue(record.hasMeasurement(for: .co2))
        XCTAssertTrue(record.hasMeasurement(for: .pm10))
        XCTAssertTrue(record.hasMeasurement(for: .pm25))
        XCTAssertTrue(record.hasMeasurement(for: .pm40))
        XCTAssertTrue(record.hasMeasurement(for: .pm100))
        XCTAssertTrue(record.hasMeasurement(for: .voc))
        XCTAssertTrue(record.hasMeasurement(for: .nox))
        XCTAssertTrue(record.hasMeasurement(for: .luminosity))
        XCTAssertTrue(record.hasMeasurement(for: .soundInstant))
        XCTAssertTrue(record.hasMeasurement(for: .voltage))
        XCTAssertTrue(record.hasMeasurement(for: .rssi))
        XCTAssertTrue(record.hasMeasurement(for: .accelerationX))
        XCTAssertFalse(record.hasMeasurement(for: .txPower))
        XCTAssertEqual(cityCountry.cityCommaCountry, "Helsinki, Finland")
        XCTAssertEqual(cityCountry.description, "Helsinki, Finland")
        XCTAssertEqual(cityState.description, "Oslo, Oslo")
        XCTAssertEqual(countryOnly.description, "Finland")
    }

    func testQueuedRequestAndSubscriptionSQLiteAdaptersPreserveValues() {
        let request = RuuviCloudQueuedRequestSQLite(
            id: 10,
            type: .sensorSettings,
            status: .failed,
            uniqueKey: "sensor-settings",
            requestDate: Date(timeIntervalSince1970: 10),
            successDate: Date(timeIntervalSince1970: 20),
            attempts: 2,
            requestBodyData: Data([0x01, 0x02]),
            additionalData: Data([0x03])
        )
        let queuedRequest = request.queuedRequest
        let sqliteRequest = queuedRequest.sqlite
        let subscription = SubscriptionStub(
            macId: "AA:BB:CC:11:22:33",
            subscriptionName: "business",
            maxHistoryDays: 730
        )
        let sqliteSubscription = subscription.sqlite

        XCTAssertEqual(queuedRequest.id, 10)
        XCTAssertEqual(queuedRequest.type, .sensorSettings)
        XCTAssertEqual(queuedRequest.status, .failed)
        XCTAssertEqual(queuedRequest.uniqueKey, "sensor-settings")
        XCTAssertEqual(queuedRequest.attempts, 2)
        XCTAssertEqual(queuedRequest.requestBodyData, Data([0x01, 0x02]))
        XCTAssertEqual(sqliteRequest.id, 10)
        XCTAssertEqual(sqliteRequest.type, .sensorSettings)
        XCTAssertEqual(sqliteRequest.status, .failed)
        XCTAssertEqual(sqliteRequest.uniqueKey, "sensor-settings")
        XCTAssertEqual(sqliteSubscription.macId, "AA:BB:CC:11:22:33")
        XCTAssertEqual(sqliteSubscription.subscriptionName, "business")
        XCTAssertEqual(sqliteSubscription.maxHistoryDays, 730)
        XCTAssertEqual(sqliteSubscription.id, "AA:BB:CC:11:22:33-subscription")
    }

    func testShareableSensorAndSQLiteHelpersCoverEqualityAndDisplayOrderRoundTrips() throws {
        let shareable = ShareableSensorStruct(
            id: "AA:BB:CC:11:22:33",
            canShare: true,
            sharedTo: ["friend@example.com"]
        )
        let sameShareable = ShareableSensorStruct(
            id: "AA:BB:CC:11:22:33",
            canShare: false,
            sharedTo: []
        )
        XCTAssertTrue(shareable.any.canShare)
        XCTAssertEqual(shareable.any, sameShareable.any)

        let subscription = RuuviCloudSensorSubscriptionSQLite(
            macId: "AA:BB:CC:11:22:33",
            subscriptionName: "business",
            isActive: true,
            maxClaims: 10,
            maxHistoryDays: 365,
            maxResolutionMinutes: 15,
            maxShares: 20,
            maxSharesPerSensor: 3,
            delayedAlertAllowed: true,
            emailAlertAllowed: true,
            offlineAlertAllowed: false,
            pdfExportAllowed: true,
            pushAlertAllowed: true,
            telegramAlertAllowed: false,
            endAt: "2099-01-01"
        )
        XCTAssertEqual(subscription, subscription)
        XCTAssertNotEqual(
            subscription,
            RuuviCloudSensorSubscriptionSQLite(
                macId: "AA:BB:CC:11:22:33",
                subscriptionName: "starter",
                isActive: true,
                maxClaims: 10,
                maxHistoryDays: 365,
                maxResolutionMinutes: 15,
                maxShares: 20,
                maxSharesPerSensor: 3,
                delayedAlertAllowed: true,
                emailAlertAllowed: true,
                offlineAlertAllowed: false,
                pdfExportAllowed: true,
                pushAlertAllowed: true,
                telegramAlertAllowed: false,
                endAt: "2099-01-01"
            )
        )

        let settings = SensorSettingsSQLite(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:11:22:33".mac,
            temperatureOffset: 1.5,
            humidityOffset: 2.5,
            pressureOffset: 3.5,
            description: "Basement",
            displayOrder: ["temperature", "humidity"],
            defaultDisplayOrder: false,
            displayOrderLastUpdated: Date(timeIntervalSince1970: 100),
            defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 200),
            descriptionLastUpdated: Date(timeIntervalSince1970: 300)
        )
        let mirrored = settings.sensorSettings
        let encoded = try XCTUnwrap(
            SensorSettingsSQLite.encodeDisplayOrder(["temperature", "humidity"])
        )

        XCTAssertEqual(mirrored.id, "AA:BB:CC:11:22:33-settings")
        XCTAssertEqual(mirrored.description, "Basement")
        XCTAssertEqual(mirrored.displayOrder ?? [], ["temperature", "humidity"])
        XCTAssertEqual(settings, settings)
        XCTAssertEqual(
            SensorSettingsSQLite.decodeDisplayOrder(encoded) ?? [],
            ["temperature", "humidity"]
        )
        XCTAssertNil(SensorSettingsSQLite.decodeDisplayOrder(""))
        XCTAssertNil(SensorSettingsSQLite.decodeDisplayOrder("not-json"))
        XCTAssertNil(SensorSettingsSQLite.encodeDisplayOrder(nil))
        XCTAssertNil(SensorSettingsSQLite.encodeDisplayOrder([]))
    }

    func testRuuviTagDataSQLiteMirrorsSensorRecordValuesAndEquatableUsesStableId() {
        let roundTripRecord = RuuviTagDataSQLite(
            luid: "luid-1".luid,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            source: .heartbeat,
            macId: "AA:BB:CC:11:22:33".mac,
            rssi: -70,
            version: 6,
            temperature: Temperature(value: 21.5, unit: .celsius),
            humidity: Humidity(relative: 0.64, temperature: Temperature(value: 21.5, unit: .celsius)),
            pressure: Pressure(value: 1001.3, unit: .hectopascals),
            acceleration: Acceleration(
                x: AccelerationMeasurement(value: 1, unit: .metersPerSecondSquared),
                y: AccelerationMeasurement(value: 2, unit: .metersPerSecondSquared),
                z: AccelerationMeasurement(value: 3, unit: .metersPerSecondSquared)
            ),
            voltage: Voltage(value: 2.95, unit: .volts),
            movementCounter: 4,
            measurementSequenceNumber: 5,
            txPower: 6,
            pm1: 1.1,
            pm25: 2.2,
            pm4: 4.4,
            pm10: 10.1,
            co2: 420,
            voc: 12,
            nox: 8,
            luminance: 150,
            dbaInstant: 45,
            dbaAvg: 40,
            dbaPeak: 55,
            temperatureOffset: 0.5,
            humidityOffset: 1.5,
            pressureOffset: 2.5
        )
        let sameIdentityRecord = RuuviTagDataSQLite(
            luid: "other-luid".luid,
            date: roundTripRecord.date,
            source: .advertisement,
            macId: "AA:BB:CC:11:22:33".mac,
            rssi: nil,
            version: 5,
            temperature: nil,
            humidity: nil,
            pressure: nil,
            acceleration: nil,
            voltage: nil,
            movementCounter: nil,
            measurementSequenceNumber: nil,
            txPower: nil,
            pm1: nil,
            pm25: nil,
            pm4: nil,
            pm10: nil,
            co2: nil,
            voc: nil,
            nox: nil,
            luminance: nil,
            dbaInstant: nil,
            dbaAvg: nil,
            dbaPeak: nil,
            temperatureOffset: 0,
            humidityOffset: 0,
            pressureOffset: 0
        )
        let mappedRecord = roundTripRecord.any.sqlite

        XCTAssertEqual(mappedRecord, roundTripRecord)
        XCTAssertEqual(roundTripRecord, sameIdentityRecord)
        XCTAssertEqual(mappedRecord.source, .heartbeat)
        XCTAssertEqual(mappedRecord.version, 6)
        XCTAssertEqual(mappedRecord.luid?.value, "luid-1")
        XCTAssertEqual(mappedRecord.macId?.value, "AA:BB:CC:11:22:33")
        XCTAssertEqual(mappedRecord.humidity?.value, roundTripRecord.humidity?.value)
        XCTAssertEqual(
            mappedRecord.acceleration?.x.value,
            roundTripRecord.acceleration?.x.value
        )
        XCTAssertEqual(mappedRecord.pm10, 10.1)
        XCTAssertEqual(mappedRecord.temperatureOffset, 0.5)
    }

    func testRuuviTagDataSQLiteRoundTripsFullRowsAndLegacyFallbackRows() throws {
        let dbQueue = try DatabaseQueue()
        let fullRecord = makeRuuviTagDataSQLite(
            luid: "luid-full".luid,
            macId: "AA:BB:CC:11:22:33".mac
        )
        let luidOnlyRecord = makeRuuviTagDataSQLite(
            luid: "luid-only".luid,
            macId: nil
        )
        let unidentifiedRecord = makeRuuviTagDataSQLite(
            luid: nil,
            macId: nil
        )

        try dbQueue.write { db in
            try RuuviTagDataSQLite.createTable(in: db)
            try fullRecord.insert(db)
            try luidOnlyRecord.insert(db)
            try unidentifiedRecord.insert(db)
        }

        try dbQueue.read { db in
            let fetched = try XCTUnwrap(
                RuuviTagDataSQLite.fetchOne(
                    db,
                    sql: "SELECT * FROM \(RuuviTagDataSQLite.databaseTableName) WHERE mac = ?",
                    arguments: ["AA:BB:CC:11:22:33"]
                )
            )
            XCTAssertEqual(fetched.luid?.value, "luid-full")
            XCTAssertEqual(fetched.macId?.value, "AA:BB:CC:11:22:33")
            XCTAssertEqual(fetched.source, .heartbeat)
            XCTAssertEqual(fetched.version, 6)
            XCTAssertEqual(fetched.temperature?.value, 21.5)
            XCTAssertEqual(fetched.humidity?.value, 0.64)
            XCTAssertEqual(fetched.pressure?.value, 1001.3)
            XCTAssertEqual(fetched.acceleration?.x.value, 1)
            XCTAssertEqual(fetched.acceleration?.y.value, 2)
            XCTAssertEqual(fetched.acceleration?.z.value, 3)
            XCTAssertEqual(fetched.voltage?.value, 2.95)
            XCTAssertEqual(fetched.pm25, 2.2)

            let storedFallbackId = try XCTUnwrap(
                String.fetchOne(
                    db,
                    sql: "SELECT ruuviTagId FROM \(RuuviTagDataSQLite.databaseTableName) WHERE luid = ?",
                    arguments: ["luid-only"]
                )
            )
            XCTAssertEqual(storedFallbackId, "luid-only")

            let storedEmptyFallbackId = try XCTUnwrap(
                String.fetchOne(
                    db,
                    sql: "SELECT ruuviTagId FROM \(RuuviTagDataSQLite.databaseTableName) WHERE id = ?",
                    arguments: [""]
                )
            )
            XCTAssertEqual(storedEmptyFallbackId, "")

            let legacyRow = try XCTUnwrap(makeLegacyDataRow(db: db, sourceSQL: "NULL"))
            XCTAssertEqual(legacyRow.luid?.value, "legacy-luid")
            XCTAssertEqual(legacyRow.source, .unknown)
            XCTAssertEqual(legacyRow.version, 5)

            let invalidSourceRow = try XCTUnwrap(makeLegacyDataRow(db: db, sourceSQL: "'invalid-source'"))
            XCTAssertEqual(invalidSourceRow.source, .unknown)
        }
    }

    func testRuuviTagLatestDataSQLiteRoundTripsFullRowsFallbackRowsAndStableEquality() throws {
        let dbQueue = try DatabaseQueue()
        let fullRecord = makeRuuviTagLatestDataSQLite(
            id: "latest-full",
            luid: "latest-luid".luid,
            macId: "AA:BB:CC:11:22:33".mac
        )
        let sameIdRecord = makeRuuviTagLatestDataSQLite(
            id: "latest-full",
            luid: "other-luid".luid,
            macId: nil
        )
        let differentIdRecord = makeRuuviTagLatestDataSQLite(
            id: "latest-different",
            luid: "latest-luid".luid,
            macId: "AA:BB:CC:11:22:33".mac
        )
        let luidOnlyRecord = makeRuuviTagLatestDataSQLite(
            id: "latest-luid-only",
            luid: "latest-luid-only".luid,
            macId: nil
        )
        let unidentifiedRecord = makeRuuviTagLatestDataSQLite(
            id: "latest-unidentified",
            luid: nil,
            macId: nil
        )

        XCTAssertEqual(fullRecord, sameIdRecord)
        XCTAssertNotEqual(fullRecord, differentIdRecord)

        try dbQueue.write { db in
            try RuuviTagLatestDataSQLite.createTable(in: db)
            try fullRecord.insert(db)
            try luidOnlyRecord.insert(db)
            try unidentifiedRecord.insert(db)
        }

        try dbQueue.read { db in
            let fetched = try XCTUnwrap(
                RuuviTagLatestDataSQLite.fetchOne(
                    db,
                    sql: "SELECT * FROM \(RuuviTagLatestDataSQLite.databaseTableName) WHERE id = ?",
                    arguments: ["latest-full"]
                )
            )
            XCTAssertEqual(fetched.luid?.value, "latest-luid")
            XCTAssertEqual(fetched.macId?.value, "AA:BB:CC:11:22:33")
            XCTAssertEqual(fetched.source, .heartbeat)
            XCTAssertEqual(fetched.version, 6)
            XCTAssertEqual(fetched.temperature?.value, 21.5)
            XCTAssertEqual(fetched.humidity?.value, 0.64)
            XCTAssertEqual(fetched.pressure?.value, 1001.3)
            XCTAssertEqual(fetched.acceleration?.x.value, 1)
            XCTAssertEqual(fetched.acceleration?.y.value, 2)
            XCTAssertEqual(fetched.acceleration?.z.value, 3)
            XCTAssertEqual(fetched.voltage?.value, 2.95)
            XCTAssertEqual(fetched.pm25, 2.2)

            let storedLuidFallbackId = try XCTUnwrap(
                String.fetchOne(
                    db,
                    sql: "SELECT ruuviTagId FROM \(RuuviTagLatestDataSQLite.databaseTableName) WHERE id = ?",
                    arguments: ["latest-luid-only"]
                )
            )
            XCTAssertEqual(storedLuidFallbackId, "latest-luid-only")

            let storedEmptyFallbackId = try XCTUnwrap(
                String.fetchOne(
                    db,
                    sql: "SELECT ruuviTagId FROM \(RuuviTagLatestDataSQLite.databaseTableName) WHERE id = ?",
                    arguments: ["latest-unidentified"]
                )
            )
            XCTAssertEqual(storedEmptyFallbackId, "")

            let legacyRow = try XCTUnwrap(makeLegacyLatestDataRow(db: db, sourceSQL: "NULL"))
            XCTAssertEqual(legacyRow.id, "legacy-latest")
            XCTAssertEqual(legacyRow.luid?.value, "legacy-luid")
            XCTAssertEqual(legacyRow.source, .unknown)
            XCTAssertEqual(legacyRow.version, 5)

            let invalidSourceRow = try XCTUnwrap(makeLegacyLatestDataRow(db: db, sourceSQL: "'invalid-source'"))
            XCTAssertEqual(invalidSourceRow.source, .unknown)
        }
    }

    func testRuuviTagSQLiteRoundTripsAndDecodesMissingSharedRecipients() throws {
        let dbQueue = try DatabaseQueue()
        let tag = RuuviTagSQLite(
            id: "sensor-id",
            macId: "AA:BB:CC:11:22:33".mac,
            luid: "sensor-luid".luid,
            serviceUUID: "service",
            name: "Kitchen",
            version: 6,
            firmwareVersion: "3.31.0+0",
            isConnectable: true,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "business",
            isCloudSensor: true,
            canShare: true,
            sharedTo: ["friend@example.com", "guest@example.com"],
            maxHistoryDays: 365,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let renamedTag = RuuviTagSQLite(
            id: "sensor-id",
            macId: "AA:BB:CC:11:22:33".mac,
            luid: "sensor-luid".luid,
            serviceUUID: "service",
            name: "Office",
            version: 6,
            firmwareVersion: "3.31.0+0",
            isConnectable: true,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "business",
            isCloudSensor: true,
            canShare: true,
            sharedTo: ["friend@example.com", "guest@example.com"],
            maxHistoryDays: 365,
            lastUpdated: tag.lastUpdated
        )

        try dbQueue.write { db in
            try RuuviTagSQLite.createTable(in: db)
            try tag.insert(db)
        }

        try dbQueue.read { db in
            let fetched = try XCTUnwrap(
                RuuviTagSQLite.fetchOne(
                    db,
                    sql: "SELECT * FROM \(RuuviTagSQLite.databaseTableName) WHERE id = ?",
                    arguments: ["sensor-id"]
                )
            )
            XCTAssertEqual(fetched, tag)
            XCTAssertNotEqual(fetched, renamedTag)
            XCTAssertEqual(fetched.sharedTo, ["friend@example.com", "guest@example.com"])

            let rowWithoutSharedRecipients = try XCTUnwrap(
                Row.fetchOne(
                    db,
                    sql: """
                    SELECT
                        'sensor-no-shares' AS id,
                        NULL AS mac,
                        'sensor-luid-only' AS luid,
                        NULL AS serviceUUID,
                        'Basement' AS name,
                        5 AS version,
                        NULL AS firmwareVersion,
                        0 AS isConnectable,
                        0 AS isClaimed,
                        1 AS isOwner,
                        NULL AS owner,
                        NULL AS ownersPlan,
                        NULL AS isCloudSensor,
                        0 AS canShare,
                        NULL AS sharedTo,
                        NULL AS maxHistoryDays,
                        ? AS lastUpdated
                    """,
                    arguments: [Date(timeIntervalSince1970: 1_700_000_200)]
                )
            )
            let decoded = RuuviTagSQLite(row: rowWithoutSharedRecipients)
            XCTAssertEqual(decoded.id, "sensor-no-shares")
            XCTAssertNil(decoded.macId)
            XCTAssertEqual(decoded.luid?.value, "sensor-luid-only")
            XCTAssertEqual(decoded.sharedTo, [])
            XCTAssertEqual(decoded.isConnectable, false)
            XCTAssertEqual(decoded.isOwner, true)
        }
    }

    func testSubscriptionQueuedRequestAndSettingsSQLiteRoundTripThroughGRDB() throws {
        let dbQueue = try DatabaseQueue()
        let subscription = RuuviCloudSensorSubscriptionSQLite(
            macId: "AA:BB:CC:11:22:33",
            subscriptionName: "business",
            isActive: true,
            maxClaims: 10,
            maxHistoryDays: 365,
            maxResolutionMinutes: 15,
            maxShares: 20,
            maxSharesPerSensor: 3,
            delayedAlertAllowed: true,
            emailAlertAllowed: false,
            offlineAlertAllowed: true,
            pdfExportAllowed: false,
            pushAlertAllowed: true,
            telegramAlertAllowed: false,
            endAt: "2099-01-01"
        )
        let queuedRequest = RuuviCloudQueuedRequestSQLite(
            id: nil,
            type: .uploadImage,
            status: .failed,
            uniqueKey: "upload-image",
            requestDate: Date(timeIntervalSince1970: 10),
            successDate: Date(timeIntervalSince1970: 20),
            attempts: 2,
            requestBodyData: Data([0x01, 0x02]),
            additionalData: Data([0x03])
        )
        let settings = SensorSettingsSQLite(
            luid: "settings-luid".luid,
            macId: "AA:BB:CC:11:22:33".mac,
            temperatureOffset: 1.5,
            humidityOffset: 2.5,
            pressureOffset: 3.5,
            description: "Basement",
            displayOrder: ["temperature", "humidity"],
            defaultDisplayOrder: false,
            displayOrderLastUpdated: Date(timeIntervalSince1970: 30),
            defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 40),
            descriptionLastUpdated: Date(timeIntervalSince1970: 50)
        )

        try dbQueue.write { db in
            try RuuviCloudSensorSubscriptionSQLite.createTable(in: db)
            try RuuviCloudQueuedRequestSQLite.createTable(in: db)
            try SensorSettingsSQLite.createTable(in: db)
            try subscription.insert(db)
            try queuedRequest.insert(db)
            try settings.insert(db)
        }

        try dbQueue.read { db in
            let fetchedSubscription = try XCTUnwrap(
                RuuviCloudSensorSubscriptionSQLite.fetchOne(
                    db,
                    sql: "SELECT * FROM \(RuuviCloudSensorSubscriptionSQLite.databaseTableName) WHERE id = ?",
                    arguments: [subscription.id]
                )
            )
            XCTAssertEqual(fetchedSubscription, subscription)
            XCTAssertEqual(fetchedSubscription.sqlite, subscription)
            XCTAssertNotEqual(
                fetchedSubscription,
                RuuviCloudSensorSubscriptionSQLite(
                    macId: "AA:BB:CC:11:22:33",
                    subscriptionName: "starter",
                    isActive: true,
                    maxClaims: 10,
                    maxHistoryDays: 365,
                    maxResolutionMinutes: 15,
                    maxShares: 20,
                    maxSharesPerSensor: 3,
                    delayedAlertAllowed: true,
                    emailAlertAllowed: false,
                    offlineAlertAllowed: true,
                    pdfExportAllowed: false,
                    pushAlertAllowed: true,
                    telegramAlertAllowed: false,
                    endAt: "2099-01-01"
                )
            )

            let fetchedRequest = try XCTUnwrap(
                RuuviCloudQueuedRequestSQLite.fetchOne(
                    db,
                    sql: "SELECT * FROM \(RuuviCloudQueuedRequestSQLite.databaseTableName) WHERE uniqueKey = ?",
                    arguments: ["upload-image"]
                )
            )
            XCTAssertEqual(fetchedRequest.type, .uploadImage)
            XCTAssertEqual(fetchedRequest.status, .failed)
            XCTAssertEqual(fetchedRequest.queuedRequest.sqlite.uniqueKey, "upload-image")
            XCTAssertEqual(fetchedRequest.requestBodyData, Data([0x01, 0x02]))

            let nilRequestRow = try XCTUnwrap(
                Row.fetchOne(
                    db,
                    sql: """
                    SELECT
                        NULL AS id,
                        NULL AS requestType,
                        NULL AS statusType,
                        NULL AS uniqueKey,
                        NULL AS requestDate,
                        NULL AS successDate,
                        NULL AS attempts,
                        NULL AS requestBodyData,
                        NULL AS additionalData
                    """
                )
            )
            let nilRequest = RuuviCloudQueuedRequestSQLite(row: nilRequestRow)
            XCTAssertEqual(nilRequest.type, RuuviCloudQueuedRequestType.none)
            XCTAssertNil(nilRequest.status)

            let fetchedSettings = try XCTUnwrap(
                SensorSettingsSQLite.fetchOne(
                    db,
                    sql: "SELECT * FROM \(SensorSettingsSQLite.databaseTableName) WHERE id = ?",
                    arguments: [settings.id]
                )
            )
            XCTAssertEqual(fetchedSettings, settings)
            XCTAssertEqual(fetchedSettings.sensorSettings.sqlite, settings)
            XCTAssertEqual(fetchedSettings.displayOrder ?? [], ["temperature", "humidity"])

            let nilDisplayOrderRow = try XCTUnwrap(
                Row.fetchOne(
                    db,
                    sql: """
                    SELECT
                        'nil-order-settings' AS id,
                        'settings-luid-only' AS luid,
                        NULL AS macId,
                        NULL AS temperatureOffset,
                        NULL AS humidityOffset,
                        NULL AS pressureOffset,
                        NULL AS description,
                        NULL AS displayOrder,
                        NULL AS defaultDisplayOrder,
                        NULL AS displayOrderLastUpdated,
                        NULL AS defaultDisplayOrderLastUpdated,
                        NULL AS descriptionLastUpdated
                    """
                )
            )
            let nilDisplayOrderSettings = SensorSettingsSQLite(row: nilDisplayOrderRow)
            XCTAssertEqual(nilDisplayOrderSettings.luid?.value, "settings-luid-only")
            XCTAssertNil(nilDisplayOrderSettings.macId)
            XCTAssertNil(nilDisplayOrderSettings.displayOrder)
        }
    }
}

private struct LocationStub: Location {
    let city: String?
    let state: String?
    let country: String?
    let coordinate = CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9384)
}

private struct SubscriptionStub: CloudSensorSubscription {
    let macId: String?
    let subscriptionName: String?
    let isActive: Bool? = true
    let maxClaims: Int? = 5
    let maxHistoryDays: Int?
    let maxResolutionMinutes: Int? = 5
    let maxShares: Int? = 10
    let maxSharesPerSensor: Int? = 3
    let delayedAlertAllowed: Bool? = true
    let emailAlertAllowed: Bool? = true
    let offlineAlertAllowed: Bool? = true
    let pdfExportAllowed: Bool? = true
    let pushAlertAllowed: Bool? = true
    let telegramAlertAllowed: Bool? = false
    let endAt: String? = "2099-01-01"
}

private struct AlertSensorStub: RuuviCloudSensorAlerts {
    let sensor: String?
    let alerts: [RuuviCloudAlert]?
}

private func makeOntologyRecord(
    macId: String?,
    sequence: Int,
    luid: LocalIdentifier? = "luid-1".luid,
    co2: Double? = 600,
    pm25: Double? = 2.2
) -> RuuviTagSensorRecord {
    let temperature = Temperature(value: 21.5, unit: .celsius)
    return RuuviTagSensorRecordStruct(
        luid: luid,
        date: Date(timeIntervalSince1970: 100),
        source: .advertisement,
        macId: macId?.mac,
        rssi: -62,
        version: 5,
        temperature: temperature,
        humidity: Humidity(value: 0.45, unit: .relative(temperature: temperature)),
        pressure: Pressure(value: 1008.5, unit: .hectopascals),
        acceleration: Acceleration(
            x: Measurement(value: 1, unit: .metersPerSecondSquared),
            y: Measurement(value: 2, unit: .metersPerSecondSquared),
            z: Measurement(value: 3, unit: .metersPerSecondSquared)
        ),
        voltage: Voltage(value: 2.95, unit: .volts),
        movementCounter: 5,
        measurementSequenceNumber: sequence,
        txPower: 4,
        pm1: 1.1,
        pm25: pm25,
        pm4: 3.3,
        pm10: 4.4,
        co2: co2,
        voc: 120,
        nox: 80,
        luminance: 150,
        dbaInstant: 50.2,
        dbaAvg: 55.3,
        dbaPeak: 62.4,
        temperatureOffset: 0,
        humidityOffset: 0,
        pressureOffset: 0
    )
}

private func makeRuuviTagDataSQLite(
    luid: LocalIdentifier?,
    macId: MACIdentifier?
) -> RuuviTagDataSQLite {
    let temperature = Temperature(value: 21.5, unit: .celsius)
    return RuuviTagDataSQLite(
        luid: luid,
        date: Date(timeIntervalSince1970: 1_700_000_000),
        source: .heartbeat,
        macId: macId,
        rssi: -70,
        version: 6,
        temperature: temperature,
        humidity: Humidity(value: 0.64, unit: .relative(temperature: temperature)),
        pressure: Pressure(value: 1001.3, unit: .hectopascals),
        acceleration: Acceleration(
            x: AccelerationMeasurement(value: 1, unit: .metersPerSecondSquared),
            y: AccelerationMeasurement(value: 2, unit: .metersPerSecondSquared),
            z: AccelerationMeasurement(value: 3, unit: .metersPerSecondSquared)
        ),
        voltage: Voltage(value: 2.95, unit: .volts),
        movementCounter: 4,
        measurementSequenceNumber: 5,
        txPower: 6,
        pm1: 1.1,
        pm25: 2.2,
        pm4: 4.4,
        pm10: 10.1,
        co2: 420,
        voc: 12,
        nox: 8,
        luminance: 150,
        dbaInstant: 45,
        dbaAvg: 40,
        dbaPeak: 55,
        temperatureOffset: 0.5,
        humidityOffset: 1.5,
        pressureOffset: 2.5
    )
}

private func makeRuuviTagLatestDataSQLite(
    id: String,
    luid: LocalIdentifier?,
    macId: MACIdentifier?
) -> RuuviTagLatestDataSQLite {
    let dataRecord = makeRuuviTagDataSQLite(luid: luid, macId: macId)
    return RuuviTagLatestDataSQLite(
        id: id,
        luid: dataRecord.luid,
        date: dataRecord.date,
        source: dataRecord.source,
        macId: dataRecord.macId,
        rssi: dataRecord.rssi,
        version: dataRecord.version,
        temperature: dataRecord.temperature,
        humidity: dataRecord.humidity,
        pressure: dataRecord.pressure,
        acceleration: dataRecord.acceleration,
        voltage: dataRecord.voltage,
        movementCounter: dataRecord.movementCounter,
        measurementSequenceNumber: dataRecord.measurementSequenceNumber,
        txPower: dataRecord.txPower,
        pm1: dataRecord.pm1,
        pm25: dataRecord.pm25,
        pm4: dataRecord.pm4,
        pm10: dataRecord.pm10,
        co2: dataRecord.co2,
        voc: dataRecord.voc,
        nox: dataRecord.nox,
        luminance: dataRecord.luminance,
        dbaInstant: dataRecord.dbaInstant,
        dbaAvg: dataRecord.dbaAvg,
        dbaPeak: dataRecord.dbaPeak,
        temperatureOffset: dataRecord.temperatureOffset,
        humidityOffset: dataRecord.humidityOffset,
        pressureOffset: dataRecord.pressureOffset
    )
}

private func makeLegacyDataRow(
    db: Database,
    sourceSQL: String
) throws -> RuuviTagDataSQLite? {
    guard let row = try Row.fetchOne(
        db,
        sql: legacySensorRecordRowSQL(idSQL: "'legacy-data'", sourceSQL: sourceSQL),
        arguments: [Date(timeIntervalSince1970: 1_700_000_001)]
    ) else {
        return nil
    }
    return RuuviTagDataSQLite(row: row)
}

private func makeLegacyLatestDataRow(
    db: Database,
    sourceSQL: String
) throws -> RuuviTagLatestDataSQLite? {
    guard let row = try Row.fetchOne(
        db,
        sql: legacySensorRecordRowSQL(idSQL: "'legacy-latest'", sourceSQL: sourceSQL),
        arguments: [Date(timeIntervalSince1970: 1_700_000_001)]
    ) else {
        return nil
    }
    return RuuviTagLatestDataSQLite(row: row)
}

private func legacySensorRecordRowSQL(
    idSQL: String,
    sourceSQL: String
) -> String {
    """
    SELECT
        \(idSQL) AS id,
        NULL AS luid,
        'legacy-luid' AS ruuviTagId,
        ? AS date,
        \(sourceSQL) AS source,
        NULL AS mac,
        NULL AS rssi,
        NULL AS version,
        NULL AS celsius,
        NULL AS relativeHumidityInPercent,
        NULL AS hectopascals,
        NULL AS accelerationX,
        NULL AS accelerationY,
        NULL AS accelerationZ,
        NULL AS volts,
        NULL AS movementCounter,
        NULL AS measurementSequenceNumber,
        NULL AS txPower,
        NULL AS pm1,
        NULL AS pm2_5,
        NULL AS pm4,
        NULL AS pm10,
        NULL AS co2,
        NULL AS voc,
        NULL AS nox,
        NULL AS luminance,
        NULL AS dbaInstant,
        NULL AS dbaAvg,
        NULL AS dbaPeak,
        0.0 AS temperatureOffset,
        0.0 AS humidityOffset,
        0.0 AS pressureOffset
    """
}
