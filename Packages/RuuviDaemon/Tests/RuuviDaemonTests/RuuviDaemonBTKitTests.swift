@testable import RuuviDaemon
import BTKit
import RuuviLocal
import RuuviNotification
import RuuviNotifier
import RuuviOntology
import RuuviPersistence
import XCTest

final class RuuviDaemonBTKitTests: XCTestCase {
    func testAdvertisementCorePrunesStateForRemovedIdentifiers() {
        let now = Date()
        let pruned = RuuviTagAdvertisementDaemonCore.pruneState(
            savedDate: ["keep": now, "remove": now],
            advertisementSequence: ["keep": 1, "remove": 2],
            keeping: ["keep"]
        )

        XCTAssertEqual(pruned.savedDate.keys.sorted(), ["keep"])
        XCTAssertEqual(pruned.advertisementSequence, ["keep": 1])
    }

    func testAdvertisementCoreRemovesCachedSensorByMatchAndFallbackIdentifier() {
        let matched = makeSensor(id: "sensor-1", luid: "luid-1", mac: "AA:BB:CC:DD:EE:FF").any
        let fallback = makeSensor(id: "fallback-id", luid: "fallback-luid", mac: "11:22:33:44:55:66").any
        let other = makeSensor(id: "sensor-3", luid: "luid-3", mac: "77:88:99:AA:BB:CC").any

        let matchedRemaining = RuuviTagAdvertisementDaemonCore.removeCachedSensor(
            matching: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"),
            fallbackUUID: "missing",
            ruuviTagsByLuid: ["luid-1".luid.any: matched],
            ruuviTags: [matched, fallback, other]
        )
        let fallbackRemaining = RuuviTagAdvertisementDaemonCore.removeCachedSensor(
            matching: makeAdvertisementTag(uuid: "missing", mac: "00:11:22:33:44:55"),
            fallbackUUID: "fallback-luid",
            ruuviTagsByLuid: [:],
            ruuviTags: [matched, fallback, other]
        )

        XCTAssertEqual(
            matchedRemaining.compactMap { $0.macId?.value }.sorted(),
            ["11:22:33:44:55:66", "77:88:99:AA:BB:CC"]
        )
        XCTAssertEqual(
            fallbackRemaining.compactMap { $0.macId?.value }.sorted(),
            ["77:88:99:AA:BB:CC", "AA:BB:CC:DD:EE:FF"]
        )
    }

    func testAdvertisementCoreFindsSensorSettingsByLuidBeforeMac() {
        let sensor = makeSensor(id: "sensor-1", luid: "luid-1", mac: "AA:BB:CC:DD:EE:FF").any
        let byMac = SensorSettingsStruct(
            luid: nil,
            macId: "AA:BB:CC:DD:EE:FF".mac,
            temperatureOffset: 1,
            humidityOffset: nil,
            pressureOffset: nil
        )
        let byLuid = SensorSettingsStruct(
            luid: "luid-1".luid,
            macId: nil,
            temperatureOffset: 2,
            humidityOffset: nil,
            pressureOffset: nil
        )

        let settings = RuuviTagAdvertisementDaemonCore.sensorSettings(
            for: sensor,
            in: [byMac, byLuid]
        )

        XCTAssertEqual(settings?.temperatureOffset, 2)
    }

    func testAdvertisementCoreSnapshotNormalizesHumidityAndRecordPlan() {
        let tag = makeAdvertisementTag(version: 5, humidity: 64.0)
        let latestOnlyTag = makeAdvertisementTag(version: 0x06, humidity: 64.0)

        let snapshot = RuuviTagAdvertisementDaemonCore.snapshot(
            from: tag,
            source: .advertisement
        )

        XCTAssertEqual(snapshot.humidity, 0.64)
        XCTAssertEqual(snapshot.temperature, 21.5)
        XCTAssertEqual(RuuviTagAdvertisementDaemonCore.recordPlan(for: tag), .historyAndLatest)
        XCTAssertEqual(RuuviTagAdvertisementDaemonCore.recordPlan(for: latestOnlyTag), .latestOnly)
    }

    func testAdvertisementCoreForegroundPersistsOnlyWhenSequenceChanges() {
        XCTAssertTrue(
            RuuviTagAdvertisementDaemonCore.shouldPersist(
                appIsOnForeground: true,
                uuid: "luid-1",
                measurementSequenceNumber: 10,
                lastSequenceNumber: 9,
                lastSavedDate: nil,
                saveInterval: 60
            )
        )
        XCTAssertFalse(
            RuuviTagAdvertisementDaemonCore.shouldPersist(
                appIsOnForeground: true,
                uuid: "luid-1",
                measurementSequenceNumber: 10,
                lastSequenceNumber: 10,
                lastSavedDate: nil,
                saveInterval: 60
            )
        )
    }

    func testAdvertisementCoreBackgroundPersistsOnlyAfterInterval() {
        let now = Date()

        XCTAssertFalse(
            RuuviTagAdvertisementDaemonCore.shouldPersist(
                appIsOnForeground: false,
                uuid: "luid-1",
                measurementSequenceNumber: 1,
                lastSequenceNumber: nil,
                lastSavedDate: now.addingTimeInterval(-30),
                saveInterval: 60,
                now: now
            )
        )
        XCTAssertTrue(
            RuuviTagAdvertisementDaemonCore.shouldPersist(
                appIsOnForeground: false,
                uuid: "luid-1",
                measurementSequenceNumber: 1,
                lastSequenceNumber: nil,
                lastSavedDate: now.addingTimeInterval(-61),
                saveInterval: 60,
                now: now
            )
        )
    }

    func testAdvertisementCoreLatestRecordPlanUsesStoredSensorMac() {
        let tag = makeAdvertisementTag(mac: "11:22:33:44:55:66")
        let sensor = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF"
        ).any

        let createPlan = RuuviTagAdvertisementDaemonCore.latestRecordPlan(
            for: tag,
            sensor: sensor,
            localRecord: nil
        )
        guard case let .createLast(createdRecord) = createPlan else {
            return XCTFail("Expected createLast plan")
        }
        XCTAssertEqual(createdRecord.macId?.value, "11:22:33:44:55:66")

        let existingRecord = tag.with(source: .advertisement)
        let updatePlan = RuuviTagAdvertisementDaemonCore.latestRecordPlan(
            for: tag,
            sensor: sensor,
            localRecord: existingRecord
        )
        guard case let .updateLast(updatedRecord) = updatePlan else {
            return XCTFail("Expected updateLast plan")
        }
        XCTAssertEqual(updatedRecord.macId?.value, "AA:BB:CC:DD:EE:FF")
    }

    func testAdvertisementCoreMatchingSensorUsesLuidIndexListFallbackAndMacFallback() {
        let indexed = makeSensor(id: "indexed", luid: "luid-1", mac: "AA:BB:CC:DD:EE:FF").any
        let listed = makeSensor(id: "listed", luid: "luid-2", mac: "11:22:33:44:55:66").any
        let macFallback = makeSensor(id: "mac", luid: nil, mac: "77:88:99:AA:BB:CC").any

        XCTAssertEqual(
            RuuviTagAdvertisementDaemonCore.matchingSensor(
                for: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"),
                ruuviTagsByLuid: ["luid-1".luid.any: indexed],
                ruuviTags: [listed, macFallback]
            )?.luid?.value,
            "luid-1"
        )
        XCTAssertEqual(
            RuuviTagAdvertisementDaemonCore.matchingSensor(
                for: makeAdvertisementTag(uuid: "luid-2", mac: "11:22:33:44:55:66"),
                ruuviTagsByLuid: [:],
                ruuviTags: [listed, macFallback]
            )?.luid?.value,
            "luid-2"
        )
        XCTAssertEqual(
            RuuviTagAdvertisementDaemonCore.matchingSensor(
                for: makeAdvertisementTag(uuid: "remote", mac: "77:88:99:AA:BB:CC"),
                ruuviTagsByLuid: [:],
                ruuviTags: [listed, macFallback]
            )?.macId?.value,
            "77:88:99:AA:BB:CC"
        )
        XCTAssertNil(
            RuuviTagAdvertisementDaemonCore.matchingSensor(
                for: makeAdvertisementTag(uuid: "missing", mac: "00:11:22:33:44:55"),
                ruuviTagsByLuid: [:],
                ruuviTags: [listed]
            )
        )
    }

    func testAdvertisementCoreSensorSettingsFallsBackToMacWhenLuidDoesNotMatch() {
        let sensor = makeSensor(id: "sensor-1", luid: "luid-1", mac: "AA:BB:CC:DD:EE:FF").any
        let settings = RuuviTagAdvertisementDaemonCore.sensorSettings(
            for: sensor,
            in: [
                SensorSettingsStruct(
                    luid: "other".luid,
                    macId: nil,
                    temperatureOffset: 1,
                    humidityOffset: nil,
                    pressureOffset: nil
                ),
                SensorSettingsStruct(
                    luid: nil,
                    macId: "AA:BB:CC:DD:EE:FF".mac,
                    temperatureOffset: 4,
                    humidityOffset: nil,
                    pressureOffset: nil
                ),
            ]
        )

        XCTAssertEqual(settings?.temperatureOffset, 4)
    }

    func testAdvertisementCoreCoversEmptyIdentifierAndNilHumidityPaths() {
        let sensorWithoutIdentifiers = makeSensor(id: "sensor-1", luid: nil, mac: nil).any
        let tagWithoutHumidity = makeAdvertisementTag(humidity: nil)
        let now = Date()

        let snapshot = RuuviTagAdvertisementDaemonCore.snapshot(
            from: tagWithoutHumidity,
            source: .advertisement
        )

        XCTAssertNil(
            RuuviTagAdvertisementDaemonCore.sensorSettings(
                for: sensorWithoutIdentifiers,
                in: [
                    SensorSettingsStruct(
                        luid: "luid-1".luid,
                        macId: "AA:BB:CC:DD:EE:FF".mac,
                        temperatureOffset: 1,
                        humidityOffset: nil,
                        pressureOffset: nil
                    ),
                ]
            )
        )
        XCTAssertNil(snapshot.humidity)
        XCTAssertTrue(
            RuuviTagAdvertisementDaemonCore.shouldPersist(
                appIsOnForeground: true,
                uuid: "luid-1",
                measurementSequenceNumber: nil,
                lastSequenceNumber: nil,
                lastSavedDate: nil,
                saveInterval: 60
            )
        )
        XCTAssertFalse(
            RuuviTagAdvertisementDaemonCore.shouldPersist(
                appIsOnForeground: false,
                uuid: "",
                measurementSequenceNumber: nil,
                lastSequenceNumber: nil,
                lastSavedDate: now.addingTimeInterval(-120),
                saveInterval: 60,
                now: now
            )
        )
        XCTAssertNil(
            RuuviTagAdvertisementDaemonCore.matchingSensor(
                for: makeAdvertisementTag(uuid: "", mac: ""),
                ruuviTagsByLuid: [:],
                ruuviTags: [sensorWithoutIdentifiers]
            )
        )
        XCTAssertNil(
            RuuviTagAdvertisementDaemonCore.matchingSensor(
                for: makeHeartbeatTag(uuid: ""),
                ruuviTagsByLuid: [:],
                ruuviTags: [sensorWithoutIdentifiers]
            )
        )
    }

    func testHeartbeatCoreMapsConnectionAndDisconnectionActions() {
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.notificationAction(for: BTConnectResult.just, alertsEnabled: true),
            .notifyDidConnect
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.notificationAction(for: BTConnectResult.disconnected, alertsEnabled: true),
            .notifyDidDisconnect
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.notificationAction(
                for: BTDisconnectResult.bluetoothWasPoweredOff,
                alertsEnabled: true
            ),
            .notifyDidDisconnect
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.notificationAction(for: BTConnectResult.already, alertsEnabled: true),
            .none
        )
    }

    func testHeartbeatCorePrunesSavedStateForRemovedIdentifiers() {
        let now = Date()
        let pruned = RuuviTagHeartbeatDaemonCore.pruneState(
            savedDate: ["keep": now, "remove": now],
            lastSavedSequenceNumbers: ["keep": 1, "remove": 2],
            keeping: ["keep"]
        )

        XCTAssertEqual(pruned.savedDate.keys.sorted(), ["keep"])
        XCTAssertEqual(pruned.lastSavedSequenceNumbers, ["keep": 1])
    }

    func testHeartbeatCorePersistencePlanSkipsDuplicateVersion5Sequence() {
        let now = Date()
        let plan = RuuviTagHeartbeatDaemonCore.persistencePlan(
            saveHeartbeats: true,
            appIsOnForeground: false,
            foregroundIntervalSeconds: 5,
            backgroundIntervalMinutes: 1,
            tagExists: true,
            uuid: "luid-1",
            hasLuid: true,
            version: 5,
            measurementSequenceNumber: 7,
            lastSavedSequenceNumber: 7,
            lastSavedDate: now.addingTimeInterval(-120),
            now: now
        )

        XCTAssertEqual(plan, .skip)
    }

    func testHeartbeatCorePersistencePlanGuardsAndCreatesVersion5WithSequence() {
        let now = Date()

        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.persistencePlan(
                saveHeartbeats: false,
                appIsOnForeground: false,
                foregroundIntervalSeconds: 5,
                backgroundIntervalMinutes: 1,
                tagExists: true,
                uuid: "luid-1",
                hasLuid: true,
                version: 5,
                measurementSequenceNumber: 8,
                lastSavedSequenceNumber: 7,
                lastSavedDate: now.addingTimeInterval(-120),
                now: now
            ),
            .skip
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.persistencePlan(
                saveHeartbeats: true,
                appIsOnForeground: false,
                foregroundIntervalSeconds: 5,
                backgroundIntervalMinutes: 1,
                tagExists: false,
                uuid: "luid-1",
                hasLuid: true,
                version: 5,
                measurementSequenceNumber: 8,
                lastSavedSequenceNumber: 7,
                lastSavedDate: now.addingTimeInterval(-120),
                now: now
            ),
            .skip
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.persistencePlan(
                saveHeartbeats: true,
                appIsOnForeground: false,
                foregroundIntervalSeconds: 5,
                backgroundIntervalMinutes: 1,
                tagExists: true,
                uuid: "",
                hasLuid: true,
                version: 5,
                measurementSequenceNumber: 8,
                lastSavedSequenceNumber: 7,
                lastSavedDate: now.addingTimeInterval(-120),
                now: now
            ),
            .skip
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.persistencePlan(
                saveHeartbeats: true,
                appIsOnForeground: false,
                foregroundIntervalSeconds: 5,
                backgroundIntervalMinutes: 1,
                tagExists: true,
                uuid: "luid-1",
                hasLuid: false,
                version: 5,
                measurementSequenceNumber: 8,
                lastSavedSequenceNumber: 7,
                lastSavedDate: now.addingTimeInterval(-120),
                now: now
            ),
            .skip
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.persistencePlan(
                saveHeartbeats: true,
                appIsOnForeground: false,
                foregroundIntervalSeconds: 5,
                backgroundIntervalMinutes: 1,
                tagExists: true,
                uuid: "luid-1",
                hasLuid: true,
                version: 5,
                measurementSequenceNumber: 8,
                lastSavedSequenceNumber: 7,
                lastSavedDate: now.addingTimeInterval(-120),
                now: now
            ),
            .create(updateSequenceNumber: 8)
        )
    }

    func testHeartbeatCorePersistencePlanAllowsVersion6WithoutSequenceUpdate() {
        let now = Date()
        let plan = RuuviTagHeartbeatDaemonCore.persistencePlan(
            saveHeartbeats: true,
            appIsOnForeground: false,
            foregroundIntervalSeconds: 5,
            backgroundIntervalMinutes: 1,
            tagExists: true,
            uuid: "luid-1",
            hasLuid: true,
            version: 0x06,
            measurementSequenceNumber: 7,
            lastSavedSequenceNumber: 7,
            lastSavedDate: now.addingTimeInterval(-120),
            now: now
        )

        XCTAssertEqual(plan, .create(updateSequenceNumber: nil))
    }

    func testHeartbeatCorePersistencePlanRespectsSaveInterval() {
        let now = Date()
        let plan = RuuviTagHeartbeatDaemonCore.persistencePlan(
            saveHeartbeats: true,
            appIsOnForeground: true,
            foregroundIntervalSeconds: 60,
            backgroundIntervalMinutes: 1,
            tagExists: true,
            uuid: "luid-1",
            hasLuid: true,
            version: 5,
            measurementSequenceNumber: 8,
            lastSavedSequenceNumber: 7,
            lastSavedDate: now.addingTimeInterval(-30),
            now: now
        )

        XCTAssertEqual(plan, .skip)
    }

    func testHeartbeatCoreFiltersBackgroundObservationTargets() {
        let eligible = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            serviceUUID: "service-1"
        ).any
        let cloudSensor = makeSensor(
            id: "sensor-2",
            luid: "luid-2",
            mac: "11:22:33:44:55:66",
            serviceUUID: "service-2",
            isCloudSensor: true
        ).any

        XCTAssertTrue(
            RuuviTagHeartbeatDaemonCore.shouldObserveInBackground(
                ruuviTag: eligible,
                appIsOnForeground: false,
                saveHeartbeats: true,
                cloudModeEnabled: false,
                isConnected: false
            )
        )
        XCTAssertFalse(
            RuuviTagHeartbeatDaemonCore.shouldObserveInBackground(
                ruuviTag: cloudSensor,
                appIsOnForeground: false,
                saveHeartbeats: true,
                cloudModeEnabled: true,
                isConnected: false
            )
        )
        XCTAssertFalse(
            RuuviTagHeartbeatDaemonCore.shouldObserveInBackground(
                ruuviTag: eligible,
                appIsOnForeground: true,
                saveHeartbeats: true,
                cloudModeEnabled: false,
                isConnected: false
            )
        )
    }

    func testHeartbeatCoreCoversDisabledNotificationsObservationAndNilSnapshotBranches() {
        let noService = makeSensor(
            id: "sensor-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            serviceUUID: nil
        ).any
        let noLuid = makeSensor(
            id: "sensor-2",
            luid: nil,
            mac: "11:22:33:44:55:66",
            serviceUUID: "service-2"
        ).any
        let connected = makeSensor(
            id: "sensor-3",
            luid: "luid-3",
            mac: "77:88:99:AA:BB:CC",
            serviceUUID: "service-3"
        ).any
        let snapshot = RuuviTagHeartbeatDaemonCore.snapshot(
            from: makeHeartbeatTag(humidity: nil),
            source: .heartbeat
        )

        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.notificationAction(
                for: BTConnectResult.just,
                alertsEnabled: false
            ),
            .none
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.notificationAction(
                for: BTConnectResult.disconnected,
                alertsEnabled: false
            ),
            .none
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.notificationAction(
                for: BTDisconnectResult.bluetoothWasPoweredOff,
                alertsEnabled: false
            ),
            .none
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.notificationAction(
                for: BTDisconnectResult.already,
                alertsEnabled: true
            ),
            .none
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.notificationAction(
                for: BTDisconnectResult.stillConnected,
                alertsEnabled: true
            ),
            .none
        )
        XCTAssertFalse(
            RuuviTagHeartbeatDaemonCore.shouldObserveInBackground(
                ruuviTag: noService,
                appIsOnForeground: false,
                saveHeartbeats: true,
                cloudModeEnabled: false,
                isConnected: false
            )
        )
        XCTAssertFalse(
            RuuviTagHeartbeatDaemonCore.shouldObserveInBackground(
                ruuviTag: noLuid,
                appIsOnForeground: false,
                saveHeartbeats: true,
                cloudModeEnabled: false,
                isConnected: false
            )
        )
        XCTAssertFalse(
            RuuviTagHeartbeatDaemonCore.shouldObserveInBackground(
                ruuviTag: connected,
                appIsOnForeground: false,
                saveHeartbeats: true,
                cloudModeEnabled: false,
                isConnected: true
            )
        )
        XCTAssertFalse(
            RuuviTagHeartbeatDaemonCore.shouldObserveInBackground(
                ruuviTag: connected,
                appIsOnForeground: false,
                saveHeartbeats: false,
                cloudModeEnabled: false,
                isConnected: false
            )
        )
        XCTAssertNil(snapshot.humidity)
        XCTAssertNil(
            RuuviTagHeartbeatDaemonCore.matchingSensor(
                for: makeAdvertisementTag(uuid: "", mac: ""),
                ruuviTagsByLuid: [:],
                ruuviTags: [noService]
            )
        )
        XCTAssertNil(
            RuuviTagHeartbeatDaemonCore.matchingSensor(
                for: makeHeartbeatTag(uuid: ""),
                ruuviTagsByLuid: [:],
                ruuviTags: [noService]
            )
        )
    }

    func testHeartbeatCoreMatchesSensorAndSettingsByMacFallback() {
        let sensor = makeSensor(id: "sensor-1", luid: nil, mac: "AA:BB:CC:DD:EE:FF").any
        let tag = makeAdvertisementTag(uuid: "luid-remote", mac: "AA:BB:CC:DD:EE:FF")
        let matchedSensor = RuuviTagHeartbeatDaemonCore.matchingSensor(
            for: tag,
            ruuviTagsByLuid: [:],
            ruuviTags: [sensor]
        )
        let matchedSettings = RuuviTagHeartbeatDaemonCore.sensorSettings(
            for: matchedSensor,
            sensorSettingsByLuid: [:],
            sensorSettingsList: [
                SensorSettingsStruct(
                    luid: nil,
                    macId: "AA:BB:CC:DD:EE:FF".mac,
                    temperatureOffset: 3,
                    humidityOffset: nil,
                    pressureOffset: nil
                )
            ]
        )

        XCTAssertEqual(matchedSensor?.macId?.value, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(matchedSettings?.temperatureOffset, 3)
    }

    func testHeartbeatCoreSensorSettingsFallsBackToMacAndNilWhenNoIdentifierMatches() {
        let sensor = makeSensor(id: "sensor-1", luid: "luid-1", mac: "AA:BB:CC:DD:EE:FF").any
        let settings = RuuviTagHeartbeatDaemonCore.sensorSettings(
            for: sensor,
            sensorSettingsByLuid: [:],
            sensorSettingsList: [
                SensorSettingsStruct(
                    luid: "other".luid,
                    macId: nil,
                    temperatureOffset: 1,
                    humidityOffset: nil,
                    pressureOffset: nil
                ),
                SensorSettingsStruct(
                    luid: nil,
                    macId: "AA:BB:CC:DD:EE:FF".mac,
                    temperatureOffset: 9,
                    humidityOffset: nil,
                    pressureOffset: nil
                ),
            ]
        )

        XCTAssertEqual(settings?.temperatureOffset, 9)
        XCTAssertNil(
            RuuviTagHeartbeatDaemonCore.sensorSettings(
                for: makeSensor(id: "sensor-2", luid: nil, mac: nil).any,
                sensorSettingsByLuid: [:],
                sensorSettingsList: [
                    SensorSettingsStruct(
                        luid: "other".luid,
                        macId: "11:22:33:44:55:66".mac,
                        temperatureOffset: 2,
                        humidityOffset: nil,
                        pressureOffset: nil
                    ),
                ]
            )
        )
    }

    func testHeartbeatNotificationActionsCoverFailuresDisabledAlertsAndEquality() {
        let error = BTError.logic(.notConnected)

        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.notificationAction(
                for: BTConnectResult.failure(error),
                alertsEnabled: true
            ),
            .postError(error)
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.notificationAction(
                for: BTDisconnectResult.failure(error),
                alertsEnabled: false
            ),
            .postError(error)
        )
        XCTAssertEqual(
            RuuviTagHeartbeatDaemonCore.notificationAction(
                for: BTDisconnectResult.just,
                alertsEnabled: false
            ),
            .none
        )
        XCTAssertEqual(
            RuuviTagHeartbeatNotificationAction.postError(.logic(.notConnected)),
            RuuviTagHeartbeatNotificationAction.postError(.logic(.connectionTimedOut))
        )
        XCTAssertNotEqual(
            RuuviTagHeartbeatNotificationAction.postError(error),
            RuuviTagHeartbeatNotificationAction.notifyDidDisconnect
        )
    }

    func testHeartbeatCoreMatchingSensorAndSettingsUseLuidBeforeFallbacks() {
        let indexed = makeSensor(id: "indexed", luid: "luid-1", mac: "AA:BB:CC:DD:EE:FF").any
        let listed = makeSensor(id: "listed", luid: "luid-2", mac: "11:22:33:44:55:66").any
        let macFallback = makeSensor(id: "mac", luid: nil, mac: "77:88:99:AA:BB:CC").any

        let byIndex = RuuviTagHeartbeatDaemonCore.matchingSensor(
            for: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"),
            ruuviTagsByLuid: ["luid-1".luid.any: indexed],
            ruuviTags: [listed, macFallback]
        )
        let byList = RuuviTagHeartbeatDaemonCore.matchingSensor(
            for: makeAdvertisementTag(uuid: "luid-2", mac: "11:22:33:44:55:66"),
            ruuviTagsByLuid: [:],
            ruuviTags: [listed, macFallback]
        )
        let byMac = RuuviTagHeartbeatDaemonCore.matchingSensor(
            for: makeAdvertisementTag(uuid: "remote", mac: "77:88:99:AA:BB:CC"),
            ruuviTagsByLuid: [:],
            ruuviTags: [listed, macFallback]
        )
        let indexedSettings = RuuviTagHeartbeatDaemonCore.sensorSettings(
            for: indexed,
            sensorSettingsByLuid: [
                "luid-1".luid.any: SensorSettingsStruct(
                    luid: "luid-1".luid,
                    macId: nil,
                    temperatureOffset: 5,
                    humidityOffset: nil,
                    pressureOffset: nil
                ),
            ],
            sensorSettingsList: []
        )
        let listSettings = RuuviTagHeartbeatDaemonCore.sensorSettings(
            for: listed,
            sensorSettingsByLuid: [:],
            sensorSettingsList: [
                SensorSettingsStruct(
                    luid: "luid-2".luid,
                    macId: nil,
                    temperatureOffset: 6,
                    humidityOffset: nil,
                    pressureOffset: nil
                ),
            ]
        )

        XCTAssertEqual(byIndex?.luid?.value, "luid-1")
        XCTAssertEqual(byList?.luid?.value, "luid-2")
        XCTAssertEqual(byMac?.macId?.value, "77:88:99:AA:BB:CC")
        XCTAssertEqual(indexedSettings?.temperatureOffset, 5)
        XCTAssertEqual(listSettings?.temperatureOffset, 6)
        XCTAssertNil(
            RuuviTagHeartbeatDaemonCore.sensorSettings(
                for: nil,
                sensorSettingsByLuid: [:],
                sensorSettingsList: []
            )
        )
    }

    func testPropertiesCoreBuildsUpdatedSensorWhenMacAppears() {
        let current = makeSensor(id: "sensor-1", luid: "luid-1", mac: nil).any
        let observed = makeAdvertisementTag(uuid: "luid-1", mac: "11:22:33:44:55:66")

        let updatedSensor = RuuviTagPropertiesDaemonCore.updatedSensor(
            current: current,
            observed: observed,
            persistedMac: "AA:BB:CC:DD:EE:FF".mac
        )

        XCTAssertEqual(updatedSensor?.macId?.value, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(updatedSensor?.version, observed.version)
    }

    func testPropertiesCoreBuildsUpdatedSensorWhenLegacyFormatReturns() {
        let current = makeSensor(id: "sensor-1", luid: "luid-1", mac: "AA:BB:CC:DD:EE:FF", version: 3).any
        let observed = makeHeartbeatTag(uuid: "luid-1", version: 5)

        let updatedSensor = RuuviTagPropertiesDaemonCore.updatedSensor(
            current: current,
            observed: observed,
            persistedMac: "AA:BB:CC:DD:EE:FF".mac
        )

        XCTAssertEqual(updatedSensor?.macId?.value, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(updatedSensor?.version, 5)
    }

    func testPropertiesCoreBuildsUpdatedSensorForVersionChangeOnly() {
        let current = makeSensor(id: "sensor-1", luid: "luid-1", mac: "AA:BB:CC:DD:EE:FF", version: 3).any
        let observed = makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF", version: 5)

        let updatedSensor = RuuviTagPropertiesDaemonCore.updatedSensor(
            current: current,
            observed: observed,
            persistedMac: nil
        )

        XCTAssertEqual(updatedSensor?.macId?.value, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(updatedSensor?.version, 5)
    }

    func testPropertiesCoreDoesNotUpdateSensorWhenMacChangesWithoutPersistedMac() {
        let current = makeSensor(id: "sensor-1", luid: "luid-1", mac: "AA:BB:CC:DD:EE:FF", version: 3).any
        let observed = makeAdvertisementTag(uuid: "luid-1", mac: "11:22:33:44:55:66", version: 5)

        let updatedSensor = RuuviTagPropertiesDaemonCore.updatedSensor(
            current: current,
            observed: observed,
            persistedMac: nil
        )

        XCTAssertNil(updatedSensor)
    }

    func testPropertiesCoreDoesNotUpdateSensorWhenLegacyFormatReturnsWithoutVersionChange() {
        let current = makeSensor(id: "sensor-1", luid: "luid-1", mac: "AA:BB:CC:DD:EE:FF", version: 5).any
        let observed = makeHeartbeatTag(uuid: "luid-1", version: 5)

        let updatedSensor = RuuviTagPropertiesDaemonCore.updatedSensor(
            current: current,
            observed: observed,
            persistedMac: "AA:BB:CC:DD:EE:FF".mac
        )

        XCTAssertNil(updatedSensor)
    }

    func testPropertiesCoreDoesNotUpdateSensorWhenEverythingMatches() {
        let current = makeSensor(id: "sensor-1", luid: "luid-1", mac: "AA:BB:CC:DD:EE:FF", version: 5).any
        let observed = makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF", version: 5)

        let updatedSensor = RuuviTagPropertiesDaemonCore.updatedSensor(
            current: current,
            observed: observed,
            persistedMac: "AA:BB:CC:DD:EE:FF".mac
        )

        XCTAssertNil(updatedSensor)
    }

    func testPropertiesCoreProcessesRemoteScanOnlyForMatchingPendingSensor() {
        let sensor = makeSensor(id: "cloud-1", luid: nil, mac: "AA:BB:CC:DD:EE:FF", serviceUUID: nil, isCloudSensor: true).any
        let matchingDevice = makeDevice(tag: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"))
        let mismatchedDevice = makeDevice(tag: makeAdvertisementTag(uuid: "luid-1", mac: "11:22:33:44:55:66"))

        XCTAssertTrue(
            RuuviTagPropertiesDaemonCore.shouldProcessRemoteScan(
                ruuviTag: sensor,
                device: matchingDevice,
                processingUUIDs: []
            )
        )
        XCTAssertFalse(
            RuuviTagPropertiesDaemonCore.shouldProcessRemoteScan(
                ruuviTag: sensor,
                device: mismatchedDevice,
                processingUUIDs: []
            )
        )
        XCTAssertFalse(
            RuuviTagPropertiesDaemonCore.shouldProcessRemoteScan(
                ruuviTag: sensor,
                device: matchingDevice,
                processingUUIDs: ["luid-1"]
            )
        )
    }

    func testPropertiesCoreRejectsRemoteScanWithoutPendingCloudIdentity() {
        let sensorWithoutMac = makeSensor(id: "cloud-1", luid: nil, mac: nil, serviceUUID: nil, isCloudSensor: true).any
        let alreadyResolvedSensor = makeSensor(
            id: "cloud-2",
            luid: "luid-2",
            mac: "AA:BB:CC:DD:EE:FF",
            serviceUUID: "service-2",
            isCloudSensor: true
        ).any
        let matchingDevice = makeDevice(tag: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"))

        XCTAssertFalse(
            RuuviTagPropertiesDaemonCore.shouldProcessRemoteScan(
                ruuviTag: sensorWithoutMac,
                device: matchingDevice,
                processingUUIDs: []
            )
        )
        XCTAssertFalse(
            RuuviTagPropertiesDaemonCore.shouldProcessRemoteScan(
                ruuviTag: alreadyResolvedSensor,
                device: matchingDevice,
                processingUUIDs: []
            )
        )
    }

    func testPropertiesCoreBuildsRemoteSensorFromScannedDevice() {
        let sensor = makeSensor(id: "cloud-1", luid: nil, mac: "AA:BB:CC:DD:EE:FF", serviceUUID: nil, isCloudSensor: true).any
        let device = makeDevice(tag: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"))

        let remoteSensor = RuuviTagPropertiesDaemonCore.makeRemoteSensor(
            from: sensor,
            device: device
        )

        XCTAssertEqual(remoteSensor?.luid?.value, "luid-1")
        XCTAssertEqual(remoteSensor?.macId?.value, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(remoteSensor?.name, "cloud-1")
        XCTAssertEqual(remoteSensor?.isCloudSensor, true)
    }

    func testPropertiesCoreDoesNotBuildRemoteSensorWithoutMacOrForLocalSensor() {
        let remoteSensorMissingMac = makeSensor(
            id: "cloud-1",
            luid: nil,
            mac: nil,
            serviceUUID: nil,
            isCloudSensor: true
        ).any
        let localSensor = makeSensor(
            id: "local-1",
            luid: "luid-1",
            mac: "AA:BB:CC:DD:EE:FF",
            serviceUUID: nil,
            isCloudSensor: false
        ).any
        let device = makeDevice(tag: makeAdvertisementTag(uuid: "luid-1", mac: "AA:BB:CC:DD:EE:FF"))

        XCTAssertNil(
            RuuviTagPropertiesDaemonCore.makeRemoteSensor(
                from: remoteSensorMissingMac,
                device: device
            )
        )
        XCTAssertNil(
            RuuviTagPropertiesDaemonCore.makeRemoteSensor(
                from: localSensor,
                device: device
            )
        )
    }

    func testPropertiesCoreMapsPoolFailuresAndPrunesMatchingSensor() {
        let sensor = makeSensor(id: "sensor-1", luid: "luid-1", mac: "AA:BB:CC:DD:EE:FF").any
        let other = makeSensor(id: "sensor-2", luid: "luid-2", mac: "11:22:33:44:55:66").any

        switch RuuviTagPropertiesDaemonCore.poolFailureAction(
            for: .ruuviPersistence(.failedToFindRuuviTag)
        ) {
        case .removeCachedSensor:
            break
        case .postError:
            XCTFail("Expected cached sensor removal")
        }

        let remaining = RuuviTagPropertiesDaemonCore.removeCachedSensor(
            matching: sensor,
            from: [sensor, other]
        )

        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.macId?.value, "11:22:33:44:55:66")
    }

    func testPropertiesCorePoolFailureWrapsUnexpectedPersistenceErrors() {
        let action = RuuviTagPropertiesDaemonCore.poolFailureAction(
            for: .ruuviPersistence(.grdb(TestError()))
        )

        switch action {
        case let .postError(error):
            guard case let .ruuviPool(poolError) = error,
                  case .ruuviPersistence(.grdb) = poolError else {
                return XCTFail("Expected wrapped pool error")
            }
        case .removeCachedSensor:
            XCTFail("Expected wrapped error")
        }
    }

    func testPropertiesIDPersistenceAdapterForwardsLookupsAndAssignments() {
        let ids = LocalIDsStub()
        let sut = PropertiesIDPersistenceAdapter(ids: ids)
        let luid = "luid-1".luid
        let mac = "AA:BB:CC:DD:EE:FF".mac

        sut.set(mac: mac, for: luid)
        sut.set(luid: luid, for: mac)

        XCTAssertEqual(sut.mac(for: luid)?.value, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(sut.luid(for: mac)?.value, "luid-1")
    }

    func testPropertiesSensorReaderAdapterReadsSensorFromPersistence() async throws {
        let persistence = PersistenceReadOneStub()
        persistence.readOneResult = makeSensor(id: "sensor-1").any
        let sut = PropertiesSensorReaderAdapter(persistence: persistence)

        let sensor = try await sut.readOne("sensor-1")

        XCTAssertEqual(persistence.readOneIDs, ["sensor-1"])
        XCTAssertEqual(sensor.name, "sensor-1")
    }

    func testHeartbeatLocalNotificationsAdapterForwardsNotificationCalls() {
        let notifications = NotificationLocalStub()
        let sut = HeartbeatLocalNotificationsAdapter(notifications: notifications)

        sut.showDidConnect(uuid: "luid-1", title: "Connected")
        sut.showDidDisconnect(uuid: "luid-1", title: "Disconnected")

        XCTAssertEqual(notifications.didConnectCalls.count, 1)
        XCTAssertEqual(notifications.didConnectCalls.first?.0, "luid-1")
        XCTAssertEqual(notifications.didConnectCalls.first?.1, "Connected")
        XCTAssertEqual(notifications.didDisconnectCalls.count, 1)
        XCTAssertEqual(notifications.didDisconnectCalls.first?.0, "luid-1")
        XCTAssertEqual(notifications.didDisconnectCalls.first?.1, "Disconnected")
    }

    func testHeartbeatConnectionsAdapterExposesPersistedUUIDs() {
        let connections = LocalConnectionsStub()
        connections.keepConnectionUUIDsStorage = ["luid-1".luid.any, "luid-2".luid.any]
        let sut = HeartbeatConnectionsAdapter(connections: connections)

        XCTAssertEqual(sut.keepConnectionUUIDs.map(\.value).sorted(), ["luid-1", "luid-2"])
    }

    func testHeartbeatNotifierAdapterForwardsNotifierProcess() {
        let notifier = NotifierStub()
        let sut = HeartbeatNotifierAdapter(notifier: notifier)
        let record = makeAdvertisementTag().with(source: .heartbeat)

        sut.process(record: record, trigger: true)

        XCTAssertEqual(notifier.processCalls.count, 1)
        XCTAssertTrue(notifier.processCalls.first?.trigger == true)
        XCTAssertEqual(notifier.processCalls.first?.record.luid?.value, record.luid?.value)
    }
}

private func makeSensor(
    id: String,
    luid: String? = "luid-1",
    mac: String? = "AA:BB:CC:DD:EE:FF",
    serviceUUID: String? = nil,
    version: Int = 5,
    isCloudSensor: Bool = false
) -> RuuviTagSensorStruct {
    RuuviTagSensorStruct(
        version: version,
        firmwareVersion: "1.0.0",
        luid: luid?.luid,
        macId: mac?.mac,
        serviceUUID: serviceUUID,
        isConnectable: true,
        name: id,
        isClaimed: true,
        isOwner: true,
        owner: "owner@example.com",
        ownersPlan: nil,
        isCloudSensor: isCloudSensor,
        canShare: false,
        sharedTo: [],
        maxHistoryDays: nil
    )
}

private func makeAdvertisementTag(
    uuid: String = "luid-1",
    mac: String = "AA:BB:CC:DD:EE:FF",
    version: Int = 5,
    sequence: Int? = 10,
    humidity: Double? = 64.0
) -> RuuviTag {
    .v5(
        RuuviData5(
            uuid: uuid,
            rssi: -42,
            isConnectable: true,
            version: version,
            humidity: humidity,
            temperature: 21.5,
            pressure: 1001.0,
            accelerationX: 1,
            accelerationY: 2,
            accelerationZ: 3,
            voltage: 2.9,
            movementCounter: 4,
            measurementSequenceNumber: sequence,
            txPower: 5,
            mac: mac
        )
    )
}

private func makeHeartbeatTag(
    uuid: String = "luid-1",
    version: Int = 5,
    sequence: Int? = 10,
    humidity: Double? = 64.0
) -> RuuviTag {
    .h5(
        RuuviHeartbeat5(
            uuid: uuid,
            isConnectable: true,
            version: version,
            humidity: humidity,
            temperature: 21.5,
            pressure: 1001.0,
            accelerationX: 1,
            accelerationY: 2,
            accelerationZ: 3,
            voltage: 2.9,
            movementCounter: 4,
            measurementSequenceNumber: sequence,
            txPower: 5
        )
    )
}

private func makeDevice(tag: RuuviTag) -> BTDevice {
    .ruuvi(.tag(tag))
}

private final class LocalIDsStub: RuuviLocalIDs {
    private var macByLuid: [AnyLocalIdentifier: MACIdentifier] = [:]
    private var luidByMac: [AnyMACIdentifier: LocalIdentifier] = [:]

    func mac(for luid: LocalIdentifier) -> MACIdentifier? {
        macByLuid[luid.any]
    }

    func set(mac: MACIdentifier, for luid: LocalIdentifier) {
        macByLuid[luid.any] = mac
    }

    func luid(for mac: MACIdentifier) -> LocalIdentifier? {
        luidByMac[mac.any]
    }

    func extendedLuid(for mac: MACIdentifier) -> LocalIdentifier? { nil }

    func set(luid: LocalIdentifier, for mac: MACIdentifier) {
        luidByMac[mac.any] = luid
    }

    func set(extendedLuid: LocalIdentifier, for mac: MACIdentifier) {}
    func fullMac(for mac: MACIdentifier) -> MACIdentifier? { nil }
    func originalMac(for fullMac: MACIdentifier) -> MACIdentifier? { nil }
    func set(fullMac: MACIdentifier, for mac: MACIdentifier) {}
    func removeFullMac(for mac: MACIdentifier) {}
}

private final class NotificationLocalStub: RuuviNotificationLocal {
    var didConnectCalls: [(String, String)] = []
    var didDisconnectCalls: [(String, String)] = []

    func setup(
        disableTitle: String,
        muteTitle: String,
        output: RuuviNotificationLocalOutput?
    ) {}

    func showDidConnect(uuid: String, title: String) {
        didConnectCalls.append((uuid, title))
    }

    func showDidDisconnect(uuid: String, title: String) {
        didDisconnectCalls.append((uuid, title))
    }

    func notifyDidMove(for uuid: String, counter: Int, title: String) {}

    func notify(
        _ reason: LowHighNotificationReason,
        _ type: AlertType,
        for uuid: String,
        title: String
    ) {}
}

private final class LocalConnectionsStub: RuuviLocalConnections {
    var keepConnectionUUIDsStorage: [AnyLocalIdentifier] = []

    var keepConnectionUUIDs: [AnyLocalIdentifier] {
        keepConnectionUUIDsStorage
    }

    func keepConnection(to luid: LocalIdentifier) -> Bool {
        keepConnectionUUIDsStorage.contains(luid.any)
    }

    func setKeepConnection(_ value: Bool, for luid: LocalIdentifier) {}
    func unpairAllConnection() {}
}

private final class NotifierStub: RuuviNotifier {
    var processCalls: [(record: RuuviTagSensorRecord, trigger: Bool)] = []

    func process(record ruuviTag: RuuviTagSensorRecord, trigger: Bool) {
        processCalls.append((ruuviTag, trigger))
    }

    func processNetwork(
        record: RuuviTagSensorRecord,
        trigger: Bool,
        for identifier: MACIdentifier
    ) {}

    func subscribe<T>(_ observer: T, to uuid: String) where T: RuuviNotifierObserver {}

    func isSubscribed<T>(_ observer: T, to uuid: String) -> Bool where T: RuuviNotifierObserver {
        false
    }

    func clearMovementHysteresis(for uuid: String) {}
}

private final class PersistenceReadOneStub: RuuviPersistence {
    var readOneResult: AnyRuuviTagSensor = makeSensor(id: "default").any
    var readOneIDs: [String] = []

    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool { true }
    func create(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool { true }
    func readAll() async throws -> [AnyRuuviTagSensor] { [] }
    func readAll(_ ruuviTagId: String) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ ruuviTagId: String, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ ruuviTagId: String, after date: Date) async throws -> [RuuviTagSensorRecord] { [] }
    func readLast(_ ruuviTagId: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { nil }
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { nil }
    func deleteLatest(_ ruuviTagId: String) async throws -> Bool { true }

    func readOne(_ ruuviTagId: String) async throws -> AnyRuuviTagSensor {
        readOneIDs.append(ruuviTagId)
        return readOneResult
    }

    func getStoredTagsCount() async throws -> Int { 0 }
    func getStoredMeasurementsCount() async throws -> Int { 0 }
    func read(_ ruuviTagId: String, after date: Date, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readDownsampled(_ ruuviTagId: String, after date: Date, with intervalMinutes: Int, pick points: Double) async throws -> [RuuviTagSensorRecord] { [] }
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? { nil }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil
        )
    }

    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil
        )
    }

    func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil
        )
    }

    func deleteOffsetCorrection(ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func save(sensorSettings: SensorSettings) async throws -> SensorSettings { sensorSettings }
    func cleanupDBSpace() async throws -> Bool { true }
    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for key: String) async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for type: RuuviCloudQueuedRequestType) async throws -> [RuuviCloudQueuedRequest] { [] }
    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool { true }
    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool { true }
    func deleteQueuedRequests() async throws -> Bool { true }
    func save(subscription: CloudSensorSubscription) async throws -> CloudSensorSubscription { subscription }
    func readSensorSubscriptionSettings(_ ruuviTag: RuuviTagSensor) async throws -> CloudSensorSubscription? { nil }
}

private struct TestError: Error {}
