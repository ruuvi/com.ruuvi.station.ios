@testable import RuuviNotification
import RuuviCloud
@testable import RuuviLocal
import RuuviOntology
import RuuviService
import RuuviStorage
import XCTest

final class RuuviNotificationStatefulTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetNotificationUserDefaults()
    }

    func testSetupRegistersCategoriesAndAssignsDelegate() {
        let notificationCenter = UserNotificationCenterSpy()
        let sut = makeSut(notificationCenter: notificationCenter)

        sut.setup(disableTitle: "Disable", muteTitle: "Mute", output: nil)

        XCTAssertTrue(notificationCenter.delegate === sut)
        XCTAssertEqual(
            Set(notificationCenter.categories.map(\.identifier)),
            [
                "com.ruuvi.station.alerts.lh",
                "com.ruuvi.station.alerts.blast",
            ]
        )
    }

    func testShowDidConnectSchedulesBlastNotificationAndMarksAlertTriggered() throws {
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let storage = StorageSpy()
        let sensor = makeSensor(luid: "luid-1", macId: "AA:BB:CC:11:22:33", name: "Basement")
        storage.readOneResult = sensor.any
        alertService.setConnection(
            description: "Sensor connected",
            for: sensor
        )
        let added = expectation(description: "notification added")
        notificationCenter.onAdd = { _ in added.fulfill() }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: storage,
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: NotificationCenter(),
            badgeUpdater: { _ in }
        )

        sut.showDidConnect(uuid: "luid-1", title: "Connected")

        wait(for: [added], timeout: 1)
        XCTAssertEqual(notificationCenter.requests.count, 1)
        let request = try XCTUnwrap(notificationCenter.requests.first)
        XCTAssertEqual(request.content.title, "Connected")
        XCTAssertEqual(request.content.subtitle, "Basement")
        XCTAssertEqual(request.content.body, "Sensor connected")
        XCTAssertEqual(request.content.categoryIdentifier, "com.ruuvi.station.alerts.blast")
        XCTAssertEqual(request.content.badge?.intValue, 1)
        XCTAssertEqual(settings.notificationsBadgeCount(), 1)
        XCTAssertNotNil(
            alertService.triggeredAt(
                for: PhysicalSensorStruct(luid: "luid-1".luid, macId: "AA:BB:CC:11:22:33".mac),
                of: AlertType.connection
            )
        )
    }

    func testNotifySchedulesLowHighNotificationAndCancelsWhenAlertTurnsOff() throws {
        let notificationCenter = UserNotificationCenterSpy()
        let observerCenter = NotificationCenter()
        let settings = RuuviLocalSettingsUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let storage = StorageSpy()
        let sensor = makeSensor(luid: "luid-1", macId: "AA:BB:CC:11:22:33", name: "Freezer")
        storage.readOneResult = sensor.any
        let physicalSensor = PhysicalSensorStruct(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:11:22:33".mac
        )
        alertService.setTemperature(description: "Sensor too cold", ruuviTag: sensor)
        let added = expectation(description: "notification added")
        let removed = expectation(description: "notification removed")
        notificationCenter.onAdd = { _ in added.fulfill() }
        notificationCenter.onRemovePending = { identifiers in
            if identifiers.contains("luid-1" + AlertType.temperature(lower: 0, upper: 0).rawValue) {
                removed.fulfill()
            }
        }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: storage,
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: observerCenter,
            badgeUpdater: { _ in }
        )
        sut.setup(disableTitle: "Disable", muteTitle: "Mute", output: nil)

        sut.notify(
            LowHighNotificationReason.low,
            AlertType.temperature(lower: 0, upper: 0),
            for: "luid-1",
            title: "Too cold"
        )

        wait(for: [added], timeout: 1)
        let request = try XCTUnwrap(notificationCenter.requests.first)
        XCTAssertEqual(
            request.identifier,
            "luid-1" + AlertType.temperature(lower: 0, upper: 0).rawValue
        )
        XCTAssertEqual(request.content.subtitle, "Freezer")
        XCTAssertEqual(request.content.body, "Sensor too cold")

        observerCenter.post(
            name: .RuuviServiceAlertDidChange,
            object: nil,
            userInfo: [
                RuuviServiceAlertDidChangeKey.type: AlertType.temperature(lower: 0, upper: 0),
                RuuviServiceAlertDidChangeKey.physicalSensor: physicalSensor,
            ]
        )

        wait(for: [removed], timeout: 1)
        XCTAssertEqual(
            notificationCenter.removedPendingIdentifiers.last,
            ["luid-1" + AlertType.temperature(lower: 0, upper: 0).rawValue]
        )
        XCTAssertEqual(
            notificationCenter.removedDeliveredIdentifiers.last,
            ["luid-1" + AlertType.temperature(lower: 0, upper: 0).rawValue]
        )
    }

    func testAlertChangeObserverCancelsEveryLowHighAlertType() {
        let notificationCenter = UserNotificationCenterSpy()
        let observerCenter = NotificationCenter()
        let settings = RuuviLocalSettingsUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let physicalSensor = PhysicalSensorStruct(
            luid: "luid-cancel".luid,
            macId: "AA:BB:CC:11:22:33".mac
        )
        let types: [AlertType] = [
            .temperature(lower: 0, upper: 0),
            .relativeHumidity(lower: 0, upper: 0),
            .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute),
            .dewPoint(lower: 0, upper: 0),
            .pressure(lower: 0, upper: 0),
            .signal(lower: 0, upper: 0),
            .batteryVoltage(lower: 0, upper: 0),
            .carbonDioxide(lower: 0, upper: 0),
            .aqi(lower: 0, upper: 0),
            .pMatter1(lower: 0, upper: 0),
            .pMatter25(lower: 0, upper: 0),
            .pMatter4(lower: 0, upper: 0),
            .pMatter10(lower: 0, upper: 0),
            .voc(lower: 0, upper: 0),
            .nox(lower: 0, upper: 0),
            .soundInstant(lower: 0, upper: 0),
            .soundAverage(lower: 0, upper: 0),
            .soundPeak(lower: 0, upper: 0),
            .luminosity(lower: 0, upper: 0),
        ]
        let removed = expectation(description: "all low/high notification requests removed")
        removed.expectedFulfillmentCount = types.count
        notificationCenter.onRemovePending = { _ in removed.fulfill() }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: StorageSpy(),
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: observerCenter,
            badgeUpdater: { _ in }
        )
        sut.setup(disableTitle: "Disable", muteTitle: "Mute", output: nil)

        for type in types {
            observerCenter.post(
                name: .RuuviServiceAlertDidChange,
                object: nil,
                userInfo: [
                    RuuviServiceAlertDidChangeKey.type: type,
                    RuuviServiceAlertDidChangeKey.physicalSensor: physicalSensor,
                ]
            )
        }

        wait(for: [removed], timeout: 2)
        XCTAssertEqual(
            notificationCenter.removedPendingIdentifiers.flatMap { $0 },
            types.map { "luid-cancel" + $0.rawValue }
        )
        XCTAssertEqual(
            notificationCenter.removedDeliveredIdentifiers.flatMap { $0 },
            types.map { "luid-cancel" + $0.rawValue }
        )
    }

    func testAlertChangeObserverCancelsUsingMacWhenLuidIsMissing() {
        let notificationCenter = UserNotificationCenterSpy()
        let observerCenter = NotificationCenter()
        let settings = RuuviLocalSettingsUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let type = AlertType.pressure(lower: 0, upper: 0)
        let physicalSensor = PhysicalSensorStruct(
            luid: nil,
            macId: "AA:BB:CC:00:11:22".mac
        )
        let removed = expectation(description: "mac-only low/high notification request removed")
        notificationCenter.onRemovePending = { identifiers in
            if identifiers == ["AA:BB:CC:00:11:22" + type.rawValue] {
                removed.fulfill()
            }
        }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: StorageSpy(),
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: observerCenter,
            badgeUpdater: { _ in }
        )
        sut.setup(disableTitle: "Disable", muteTitle: "Mute", output: nil)

        observerCenter.post(
            name: .RuuviServiceAlertDidChange,
            object: nil,
            userInfo: [
                RuuviServiceAlertDidChangeKey.type: type,
                RuuviServiceAlertDidChangeKey.physicalSensor: physicalSensor,
            ]
        )

        wait(for: [removed], timeout: 1)
        XCTAssertEqual(
            notificationCenter.removedDeliveredIdentifiers.last,
            ["AA:BB:CC:00:11:22" + type.rawValue]
        )
    }

    func testSystemDefaultAlertSoundBranchesScheduleAllNotificationKinds() {
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        settings.alertSound = .systemDefault
        settings.limitAlertNotificationsEnabled = false
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let storage = StorageSpy()
        let sensor = makeSensor(luid: "luid-system-sound", macId: "AA:BB:CC:AA:BB:CC", name: "Kitchen")
        storage.readOneResult = sensor.any
        alertService.setConnection(description: "Connection", for: sensor)
        alertService.setMovement(description: "Movement", for: sensor)
        alertService.setTemperature(description: "Temperature", ruuviTag: sensor)
        let added = expectation(description: "system default sound notifications added")
        added.expectedFulfillmentCount = 4
        notificationCenter.onAdd = { _ in added.fulfill() }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: storage,
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: NotificationCenter(),
            badgeUpdater: { _ in }
        )

        sut.showDidConnect(uuid: "luid-system-sound", title: "Connected")
        sut.showDidDisconnect(uuid: "luid-system-sound", title: "Disconnected")
        sut.notifyDidMove(for: "luid-system-sound", counter: 1, title: "Moved")
        sut.notify(
            .high,
            .temperature(lower: 0, upper: 0),
            for: "luid-system-sound",
            title: "Temperature"
        )

        wait(for: [added], timeout: 2)
        XCTAssertEqual(notificationCenter.requests.count, 4)
    }

    func testBlastNotificationsUseEmptyBodyWhenDescriptionsAreMissing() {
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        settings.limitAlertNotificationsEnabled = false
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let storage = StorageSpy()
        storage.readOneResult = makeSensor(
            luid: "luid-empty-blast",
            macId: "AA:BB:CC:01:23:45",
            name: "Basement"
        ).any
        let added = expectation(description: "blast notifications added")
        added.expectedFulfillmentCount = 3
        notificationCenter.onAdd = { _ in added.fulfill() }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: storage,
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: NotificationCenter(),
            badgeUpdater: { _ in }
        )

        sut.showDidConnect(uuid: "luid-empty-blast", title: "Connected")
        sut.showDidDisconnect(uuid: "luid-empty-blast", title: "Disconnected")
        sut.notifyDidMove(for: "luid-empty-blast", counter: 1, title: "Moved")

        wait(for: [added], timeout: 1)
        XCTAssertEqual(notificationCenter.requests.count, 3)
        XCTAssertTrue(notificationCenter.requests.allSatisfy { $0.content.body == "" })
    }

    func testShowDidConnectDoesNotScheduleNotificationWhenRecentAlertIsMutedByIntervalLimit() {
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        settings.limitAlertNotificationsEnabled = true
        settings.alertsMuteIntervalMinutes = 60
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let physicalSensor = PhysicalSensorStruct(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:11:22:33".mac
        )
        alertService.trigger(
            type: .connection,
            trigerred: true,
            trigerredAt: notificationTimestampString(from: Date()),
            for: physicalSensor
        )
        let added = expectation(description: "notification added")
        added.isInverted = true
        notificationCenter.onAdd = { _ in added.fulfill() }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: StorageSpy(),
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: NotificationCenter(),
            badgeUpdater: { _ in }
        )

        sut.showDidConnect(uuid: "luid-1", title: "Connected")

        wait(for: [added], timeout: 0.3)
        XCTAssertTrue(notificationCenter.requests.isEmpty)
    }

    func testMutedTillBranchAllowsNotificationWhenLimitIntervalHasPassed() throws {
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let storage = StorageSpy()
        let sensor = makeSensor(luid: "luid-muted-branch", macId: "AA:BB:CC:10:20:30", name: "Sauna")
        storage.readOneResult = sensor.any
        let physicalSensor = PhysicalSensorStruct(
            luid: "luid-muted-branch".luid,
            macId: "AA:BB:CC:10:20:30".mac
        )
        alertService.setConnection(description: "Connection restored", for: sensor)
        alertService.mute(
            type: .connection,
            for: physicalSensor,
            till: Date().addingTimeInterval(60)
        )
        let added = expectation(description: "muted branch still completes current behavior")
        notificationCenter.onAdd = { _ in added.fulfill() }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: storage,
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: NotificationCenter(),
            badgeUpdater: { _ in }
        )

        sut.showDidConnect(uuid: "luid-muted-branch", title: "Connected")

        wait(for: [added], timeout: 1)
        let request = try XCTUnwrap(notificationCenter.requests.first)
        XCTAssertEqual(request.content.body, "Connection restored")
    }

    func testShowDidDisconnectSchedulesBlastNotificationAndMarksAlertTriggered() throws {
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let storage = StorageSpy()
        let sensor = makeSensor(luid: "luid-2", macId: "AA:BB:CC:44:55:66", name: "Garage")
        storage.readOneResult = sensor.any
        alertService.setConnection(description: "Sensor disconnected", for: sensor)
        let added = expectation(description: "disconnect notification added")
        notificationCenter.onAdd = { _ in added.fulfill() }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: storage,
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: NotificationCenter(),
            badgeUpdater: { _ in }
        )

        sut.showDidDisconnect(uuid: "luid-2", title: "Disconnected")

        wait(for: [added], timeout: 1)
        waitUntil(timeout: 1) {
            alertService.triggeredAt(
                for: PhysicalSensorStruct(luid: "luid-2".luid, macId: "AA:BB:CC:44:55:66".mac),
                of: AlertType.connection
            ) != nil
        }
        let request = try XCTUnwrap(notificationCenter.requests.first)
        XCTAssertEqual(request.content.title, "Disconnected")
        XCTAssertEqual(request.content.subtitle, "Garage")
        XCTAssertEqual(request.content.body, "Sensor disconnected")
        XCTAssertEqual(request.content.categoryIdentifier, "com.ruuvi.station.alerts.blast")
        XCTAssertNotNil(
            alertService.triggeredAt(
                for: PhysicalSensorStruct(luid: "luid-2".luid, macId: "AA:BB:CC:44:55:66".mac),
                of: AlertType.connection
            )
        )
    }

    func testNotifyDidMoveSchedulesBlastNotificationAndMarksAlertTriggered() throws {
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let storage = StorageSpy()
        let sensor = makeSensor(luid: "luid-3", macId: "AA:BB:CC:77:88:99", name: "Hallway")
        storage.readOneResult = sensor.any
        alertService.setMovement(description: "Movement detected", for: sensor)
        let added = expectation(description: "movement notification added")
        notificationCenter.onAdd = { _ in added.fulfill() }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: storage,
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: NotificationCenter(),
            badgeUpdater: { _ in }
        )

        sut.notifyDidMove(for: "luid-3", counter: 7, title: "Movement")

        wait(for: [added], timeout: 1)
        waitUntil(timeout: 1) {
            alertService.triggeredAt(
                for: PhysicalSensorStruct(luid: "luid-3".luid, macId: "AA:BB:CC:77:88:99".mac),
                of: AlertType.movement(last: 0)
            ) != nil
        }
        let request = try XCTUnwrap(notificationCenter.requests.first)
        XCTAssertEqual(request.content.title, "Movement")
        XCTAssertEqual(request.content.subtitle, "Hallway")
        XCTAssertEqual(request.content.body, "Movement detected")
        XCTAssertEqual(request.content.categoryIdentifier, "com.ruuvi.station.alerts.blast")
        XCTAssertNotNil(
            alertService.triggeredAt(
                for: PhysicalSensorStruct(luid: "luid-3".luid, macId: "AA:BB:CC:77:88:99".mac),
                of: AlertType.movement(last: 0)
            )
        )
    }

    func testNotifyCoversAllLowHighBodyDescriptions() {
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let storage = StorageSpy()
        let sensor = makeSensor(luid: "luid-4", macId: "AA:BB:CC:99:88:77", name: "Workshop")
        storage.readOneResult = sensor.any
        let expectedRequests = [
            (AlertType.temperature(lower: 0, upper: 0), "temperature"),
            (AlertType.relativeHumidity(lower: 0, upper: 0), "relative humidity"),
            (AlertType.humidity(lower: .zeroAbsolute, upper: .zeroAbsolute), "absolute humidity"),
            (AlertType.dewPoint(lower: 0, upper: 0), "dew point"),
            (AlertType.pressure(lower: 0, upper: 0), "pressure"),
            (AlertType.signal(lower: 0, upper: 0), "signal"),
            (AlertType.batteryVoltage(lower: 0, upper: 0), "battery"),
            (AlertType.aqi(lower: 0, upper: 0), "aqi"),
            (AlertType.carbonDioxide(lower: 0, upper: 0), "co2"),
            (AlertType.pMatter1(lower: 0, upper: 0), "pm1"),
            (AlertType.pMatter25(lower: 0, upper: 0), "pm25"),
            (AlertType.pMatter4(lower: 0, upper: 0), "pm4"),
            (AlertType.pMatter10(lower: 0, upper: 0), "pm10"),
            (AlertType.voc(lower: 0, upper: 0), "voc"),
            (AlertType.nox(lower: 0, upper: 0), "nox"),
            (AlertType.soundInstant(lower: 0, upper: 0), "sound instant"),
            (AlertType.soundAverage(lower: 0, upper: 0), "sound average"),
            (AlertType.soundPeak(lower: 0, upper: 0), "sound peak"),
            (AlertType.luminosity(lower: 0, upper: 0), "luminosity"),
        ]
        let added = expectation(description: "all notifications added")
        added.expectedFulfillmentCount = expectedRequests.count
        notificationCenter.onAdd = { _ in added.fulfill() }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: storage,
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: NotificationCenter(),
            badgeUpdater: { _ in }
        )

        alertService.setTemperature(description: "temperature", ruuviTag: sensor)
        alertService.setRelativeHumidity(description: "relative humidity", ruuviTag: sensor)
        alertService.setHumidity(description: "absolute humidity", for: sensor)
        alertService.setDewPoint(description: "dew point", ruuviTag: sensor)
        alertService.setPressure(description: "pressure", ruuviTag: sensor)
        alertService.setSignal(description: "signal", ruuviTag: sensor)
        alertService.setBatteryVoltage(description: "battery", ruuviTag: sensor)
        alertService.setAQI(description: "aqi", ruuviTag: sensor)
        alertService.setCarbonDioxide(description: "co2", ruuviTag: sensor)
        alertService.setPM1(description: "pm1", ruuviTag: sensor)
        alertService.setPM25(description: "pm25", ruuviTag: sensor)
        alertService.setPM4(description: "pm4", ruuviTag: sensor)
        alertService.setPM10(description: "pm10", ruuviTag: sensor)
        alertService.setVOC(description: "voc", ruuviTag: sensor)
        alertService.setNOX(description: "nox", ruuviTag: sensor)
        alertService.setSoundInstant(description: "sound instant", ruuviTag: sensor)
        alertService.setSoundAverage(description: "sound average", ruuviTag: sensor)
        alertService.setSoundPeak(description: "sound peak", ruuviTag: sensor)
        alertService.setLuminosity(description: "luminosity", ruuviTag: sensor)

        for (type, _) in expectedRequests {
            sut.notify(.high, type, for: "luid-4", title: "Triggered")
        }

        wait(for: [added], timeout: 2)
        XCTAssertEqual(notificationCenter.requests.count, expectedRequests.count)
        let bodiesByIdentifier = Dictionary(
            uniqueKeysWithValues: notificationCenter.requests.map { ($0.identifier, $0.content.body) }
        )
        for (type, expectedBody) in expectedRequests {
            XCTAssertEqual(bodiesByIdentifier["luid-4" + type.rawValue], expectedBody)
        }
    }

    func testNotifyUsesEmptyBodyForAllLowHighTypesWhenDescriptionsAreMissing() {
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        settings.limitAlertNotificationsEnabled = false
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let storage = StorageSpy()
        storage.readOneResult = makeSensor(
            luid: "luid-empty-lowhigh",
            macId: "AA:BB:CC:54:32:10",
            name: "Workshop"
        ).any
        let types: [AlertType] = [
            .temperature(lower: 0, upper: 0),
            .relativeHumidity(lower: 0, upper: 0),
            .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute),
            .dewPoint(lower: 0, upper: 0),
            .pressure(lower: 0, upper: 0),
            .signal(lower: 0, upper: 0),
            .batteryVoltage(lower: 0, upper: 0),
            .aqi(lower: 0, upper: 0),
            .carbonDioxide(lower: 0, upper: 0),
            .pMatter1(lower: 0, upper: 0),
            .pMatter25(lower: 0, upper: 0),
            .pMatter4(lower: 0, upper: 0),
            .pMatter10(lower: 0, upper: 0),
            .voc(lower: 0, upper: 0),
            .nox(lower: 0, upper: 0),
            .soundInstant(lower: 0, upper: 0),
            .soundAverage(lower: 0, upper: 0),
            .soundPeak(lower: 0, upper: 0),
            .luminosity(lower: 0, upper: 0),
        ]
        let added = expectation(description: "empty-body low/high notifications added")
        added.expectedFulfillmentCount = types.count
        notificationCenter.onAdd = { _ in added.fulfill() }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: storage,
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: NotificationCenter(),
            badgeUpdater: { _ in }
        )

        for type in types {
            sut.notify(.high, type, for: "luid-empty-lowhigh", title: "Triggered")
        }

        wait(for: [added], timeout: 2)
        XCTAssertEqual(notificationCenter.requests.count, types.count)
        XCTAssertTrue(notificationCenter.requests.allSatisfy { $0.content.body == "" })
    }

    func testNotifyDefaultBodyAndObserverNoopBranches() throws {
        let notificationCenter = UserNotificationCenterSpy()
        let observerCenter = NotificationCenter()
        let settings = RuuviLocalSettingsUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let storage = StorageSpy()
        let sensor = makeSensor(luid: "luid-default-body", macId: "AA:BB:CC:12:34:56", name: "Cloud")
        storage.readOneResult = sensor.any
        let added = expectation(description: "default-body notification added")
        notificationCenter.onAdd = { _ in added.fulfill() }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: storage,
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: observerCenter,
            badgeUpdater: { _ in }
        )
        sut.setup(disableTitle: "Disable", muteTitle: "Mute", output: nil)

        sut.notify(
            .high,
            .cloudConnection(unseenDuration: 60),
            for: "luid-default-body",
            title: "Cloud connection"
        )
        observerCenter.post(name: .RuuviServiceAlertDidChange, object: nil, userInfo: [:])
        observerCenter.post(
            name: .RuuviServiceAlertDidChange,
            object: nil,
            userInfo: [
                RuuviServiceAlertDidChangeKey.type: AlertType.connection,
                RuuviServiceAlertDidChangeKey.physicalSensor: PhysicalSensorStruct(
                    luid: "luid-default-body".luid,
                    macId: "AA:BB:CC:12:34:56".mac
                ),
            ]
        )

        wait(for: [added], timeout: 1)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        let request = try XCTUnwrap(notificationCenter.requests.first)
        XCTAssertEqual(request.content.body, "")
        XCTAssertTrue(notificationCenter.removedPendingIdentifiers.isEmpty)
    }

    func testPresentationOptionsSuppressBannerAndSoundForLocalAlertsWhenLimitDisabled() {
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        settings.limitAlertNotificationsEnabled = false
        let localIDs = RuuviLocalIDsUserDefaults()
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: StorageSpy(),
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: makeAlertService(settings: settings, localIDs: localIDs),
            userNotificationCenter: notificationCenter,
            observerCenter: NotificationCenter(),
            badgeUpdater: { _ in }
        )

        let alertOptions = sut.presentationOptions(forCategoryIdentifier: "com.ruuvi.station.alerts.lh")
        let otherOptions = sut.presentationOptions(forCategoryIdentifier: "custom.category")

        XCTAssertEqual(alertOptions.rawValue, UNNotificationPresentationOptions([.list, .badge]).rawValue)
        XCTAssertEqual(
            otherOptions.rawValue,
            UNNotificationPresentationOptions([.banner, .list, .badge, .sound]).rawValue
        )
    }

    func testHandleNotificationResponseDisablesAlertPostsTapAndForwardsPushTap() {
        let observerCenter = NotificationCenter()
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let sensor = makeSensor(luid: "luid-5", macId: "AA:BB:CC:22:33:44", name: "Office")
        alertService.register(type: .temperature(lower: 0, upper: 10), ruuviTag: sensor)
        let output = OutputSpy()
        let didReceive = expectation(description: "local notification tap posted")
        let pushTap = expectation(description: "push notification tap forwarded")
        let token = observerCenter.addObserver(
            forName: .LNMDidReceive,
            object: nil,
            queue: .main
        ) { notification in
            let uuid = notification.userInfo?[LNMDidReceiveKey.uuid] as? String
            if uuid == "luid-5" {
                didReceive.fulfill()
            }
        }
        output.onTap = { uuid in
            if uuid == "AA:BB:CC:22:33:44" {
                pushTap.fulfill()
            }
        }
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: StorageSpy(readOneResult: sensor.any),
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: observerCenter,
            badgeUpdater: { _ in }
        )
        sut.setup(disableTitle: "Disable", muteTitle: "Mute", output: output)

        sut.handleNotificationResponse(
            userInfo: [
                "com.ruuvi.station.alerts.lh.uuid": "luid-5",
                "com.ruuvi.station.alerts.lh.type": AlertType.temperature(lower: 0, upper: 0).rawValue,
            ],
            actionIdentifier: "com.ruuvi.station.alerts.lh.disable"
        )
        sut.handleNotificationResponse(
            userInfo: ["id": "AA:BB:CC:22:33:44"],
            actionIdentifier: "tap"
        )

        wait(for: [didReceive, pushTap], timeout: 1)
        waitUntil(timeout: 1) {
            !alertService.isOn(
                type: .temperature(lower: 0, upper: 0),
                for: PhysicalSensorStruct(luid: "luid-5".luid, macId: "AA:BB:CC:22:33:44".mac)
            )
        }
        observerCenter.removeObserver(token)
        XCTAssertFalse(
            alertService.isOn(
                type: .temperature(lower: 0, upper: 0),
                for: PhysicalSensorStruct(luid: "luid-5".luid, macId: "AA:BB:CC:22:33:44".mac)
            )
        )
        XCTAssertEqual(output.tappedUUIDs, ["luid-5", "AA:BB:CC:22:33:44"])
    }

    func testHandleNotificationResponseMutesBlastAlertsAndForwardsTap() {
        let observerCenter = NotificationCenter()
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        settings.alertsMuteIntervalMinutes = 30
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let sensor = makeSensor(luid: "luid-6", macId: "AA:BB:CC:55:66:77", name: "Porch")
        let output = OutputSpy()
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: StorageSpy(readOneResult: sensor.any),
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: observerCenter,
            badgeUpdater: { _ in }
        )
        sut.setup(disableTitle: "Disable", muteTitle: "Mute", output: output)

        sut.handleNotificationResponse(
            userInfo: [
                "com.ruuvi.station.alerts.blast.uuid": "luid-6",
                "com.ruuvi.station.alerts.blast.type": "connection",
            ],
            actionIdentifier: "com.ruuvi.station.alerts.blast.mute"
        )

        waitUntil(timeout: 1) {
            alertService.mutedTill(type: .connection, for: "luid-6") != nil
        }
        XCTAssertEqual(output.tappedUUIDs, ["luid-6"])
        XCTAssertNotNil(alertService.mutedTill(type: .connection, for: "luid-6"))
    }

    func testHandleNotificationResponseIgnoresUnknownActionIdentifiersButStillForwardsTap() {
        let observerCenter = NotificationCenter()
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let output = OutputSpy()
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: StorageSpy(),
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: observerCenter,
            badgeUpdater: { _ in }
        )
        sut.setup(disableTitle: "Disable", muteTitle: "Mute", output: output)

        sut.handleNotificationResponse(
            userInfo: [
                "com.ruuvi.station.alerts.lh.uuid": "luid-unknown-lh",
                "com.ruuvi.station.alerts.lh.type": AlertType.temperature(lower: 0, upper: 0).rawValue,
            ],
            actionIdentifier: "unknown.lowhigh.action"
        )
        sut.handleNotificationResponse(
            userInfo: [
                "com.ruuvi.station.alerts.blast.uuid": "luid-unknown-blast",
                "com.ruuvi.station.alerts.blast.type": "movement",
            ],
            actionIdentifier: "unknown.blast.action"
        )

        XCTAssertEqual(output.tappedUUIDs, ["luid-unknown-lh", "luid-unknown-blast"])
    }

    func testHandleNotificationResponseMutesLowHighAndDisablesBlastAlerts() {
        let observerCenter = NotificationCenter()
        let notificationCenter = UserNotificationCenterSpy()
        let settings = RuuviLocalSettingsUserDefaults()
        settings.alertsMuteIntervalMinutes = 45
        let localIDs = RuuviLocalIDsUserDefaults()
        let alertService = makeAlertService(settings: settings, localIDs: localIDs)
        let sensor = makeSensor(luid: "luid-7", macId: "AA:BB:CC:88:99:00", name: "Attic")
        alertService.register(type: .connection, ruuviTag: sensor)
        let sut = RuuviNotificationLocalImpl(
            ruuviStorage: StorageSpy(readOneResult: sensor.any),
            idPersistence: localIDs,
            settings: settings,
            ruuviAlertService: alertService,
            userNotificationCenter: notificationCenter,
            observerCenter: observerCenter,
            badgeUpdater: { _ in }
        )
        sut.setup(disableTitle: "Disable", muteTitle: "Mute", output: nil)

        sut.handleNotificationResponse(
            userInfo: [
                "com.ruuvi.station.alerts.lh.uuid": "luid-7",
                "com.ruuvi.station.alerts.lh.type": AlertType.pressure(lower: 0, upper: 0).rawValue,
            ],
            actionIdentifier: "com.ruuvi.station.alerts.lh.mute"
        )
        sut.handleNotificationResponse(
            userInfo: [
                "com.ruuvi.station.alerts.blast.uuid": "luid-7",
                "com.ruuvi.station.alerts.blast.type": "connection",
            ],
            actionIdentifier: "com.ruuvi.station.alerts.blast.disable"
        )

        waitUntil(timeout: 1) {
            alertService.mutedTill(type: .pressure(lower: 0, upper: 0), for: "luid-7") != nil
        }
        waitUntil(timeout: 1) {
            !alertService.isOn(
                type: .connection,
                for: PhysicalSensorStruct(luid: "luid-7".luid, macId: "AA:BB:CC:88:99:00".mac)
            )
        }
        XCTAssertNotNil(alertService.mutedTill(type: .pressure(lower: 0, upper: 0), for: "luid-7"))
        XCTAssertFalse(
            alertService.isOn(
                type: .connection,
                for: PhysicalSensorStruct(luid: "luid-7".luid, macId: "AA:BB:CC:88:99:00".mac)
            )
        )
    }
}

private func makeAlertService(
    settings: RuuviLocalSettings,
    localIDs: RuuviLocalIDs
) -> RuuviServiceAlertImpl {
    RuuviServiceAlertImpl(
        cloud: NoOpCloud(),
        localIDs: localIDs,
        ruuviLocalSettings: settings
    )
}

private func makeSut(
    notificationCenter: UserNotificationCenterSpy
) -> RuuviNotificationLocalImpl {
    let settings = RuuviLocalSettingsUserDefaults()
    let localIDs = RuuviLocalIDsUserDefaults()
    return RuuviNotificationLocalImpl(
        ruuviStorage: StorageSpy(),
        idPersistence: localIDs,
        settings: settings,
        ruuviAlertService: makeAlertService(settings: settings, localIDs: localIDs),
        userNotificationCenter: notificationCenter,
        observerCenter: NotificationCenter(),
        badgeUpdater: { _ in }
    )
}

private func makeSensor(
    luid: String,
    macId: String,
    name: String
) -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: 5,
        firmwareVersion: "1.0.0",
        luid: luid.luid,
        macId: macId.mac,
        serviceUUID: nil,
        isConnectable: true,
        name: name,
        isClaimed: false,
        isOwner: false,
        owner: nil,
        ownersPlan: nil,
        isCloudSensor: false,
        canShare: false,
        sharedTo: [],
        maxHistoryDays: nil
    )
}

private func notificationTimestampString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.autoupdatingCurrent
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    return formatter.string(from: date)
}

private func resetNotificationUserDefaults() {
    for key in UserDefaults.standard.dictionaryRepresentation().keys {
        UserDefaults.standard.removeObject(forKey: key)
    }
    if let appGroup = UserDefaults(suiteName: "group.com.ruuvi.station.pnservice") {
        for key in appGroup.dictionaryRepresentation().keys {
            appGroup.removeObject(forKey: key)
        }
    }
}

private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
}

private final class UserNotificationCenterSpy: UserNotificationCentering {
    private let lock = NSLock()
    private var _categories: [UNNotificationCategory] = []
    private var _requests: [UNNotificationRequest] = []
    private var _removedPendingIdentifiers: [[String]] = []
    private var _removedDeliveredIdentifiers: [[String]] = []
    private var _badgeCount: Int?

    weak var delegate: UNUserNotificationCenterDelegate?
    var onAdd: ((UNNotificationRequest) -> Void)?
    var onRemovePending: (([String]) -> Void)?

    var categories: [UNNotificationCategory] {
        lock.withLock { _categories }
    }

    var requests: [UNNotificationRequest] {
        lock.withLock { _requests }
    }

    var removedPendingIdentifiers: [[String]] {
        lock.withLock { _removedPendingIdentifiers }
    }

    var removedDeliveredIdentifiers: [[String]] {
        lock.withLock { _removedDeliveredIdentifiers }
    }

    var badgeCount: Int? {
        lock.withLock { _badgeCount }
    }

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: ((Error?) -> Void)?
    ) {
        lock.withLock {
            _requests.append(request)
        }
        onAdd?(request)
        completionHandler?(nil)
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        lock.withLock {
            _categories = Array(categories)
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        lock.withLock {
            _removedPendingIdentifiers.append(identifiers)
        }
        onRemovePending?(identifiers)
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        lock.withLock {
            _removedDeliveredIdentifiers.append(identifiers)
        }
    }

    func setBadgeCount(_ badgeCount: Int) {
        lock.withLock {
            _badgeCount = badgeCount
        }
    }
}

private extension NSLock {
    func withLock<T>(_ work: () -> T) -> T {
        lock()
        defer { unlock() }
        return work()
    }
}

private final class OutputSpy: RuuviNotificationLocalOutput {
    var tappedUUIDs: [String] = []
    var onTap: ((String) -> Void)?

    func notificationDidTap(for uuid: String) {
        tappedUUIDs.append(uuid)
        onTap?(uuid)
    }
}

private final class StorageSpy: RuuviStorage {
    var readOneResult: AnyRuuviTagSensor

    init(
        readOneResult: AnyRuuviTagSensor = makeSensor(
            luid: "luid-1",
            macId: "AA:BB:CC:11:22:33",
            name: "Sensor"
        ).any
    ) {
        self.readOneResult = readOneResult
    }

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

    func readAll(_ id: String) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ id: String, with interval: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll(_ id: String, after date: Date) async throws -> [RuuviTagSensorRecord] { [] }
    func readAll() async throws -> [AnyRuuviTagSensor] { [] }
    func readLast(_ id: String, from: TimeInterval) async throws -> [RuuviTagSensorRecord] { [] }
    func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { nil }
    func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? { nil }
    func getStoredTagsCount() async throws -> Int { 0 }
    func getClaimedTagsCount() async throws -> Int { 0 }
    func getOfflineTagsCount() async throws -> Int { 0 }
    func getStoredMeasurementsCount() async throws -> Int { 0 }
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? { nil }
    func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for key: String) async throws -> [RuuviCloudQueuedRequest] { [] }
    func readQueuedRequests(for type: RuuviCloudQueuedRequestType) async throws -> [RuuviCloudQueuedRequest] { [] }
}

private final class NoOpCloud: RuuviCloud {
    func requestCode(email: String) async throws -> String? { nil }
    func validateCode(code: String) async throws -> ValidateCodeResponse {
        ValidateCodeResponse(email: "", apiKey: "")
    }
    func deleteAccount(email: String) async throws -> Bool { true }
    func registerPNToken(
        token: String,
        type: String,
        name: String?,
        data: String?,
        params: [String: String]?
    ) async throws -> Int { 0 }
    func unregisterPNToken(token: String?, tokenId: Int?) async throws -> Bool { true }
    func listPNTokens() async throws -> [RuuviCloudPNToken] { [] }
    func loadSensors() async throws -> [AnyCloudSensor] { [] }
    func loadSensorsDense(
        for sensor: RuuviTagSensor?,
        measurements: Bool?,
        sharedToOthers: Bool?,
        sharedToMe: Bool?,
        alerts: Bool?,
        settings: Bool?
    ) async throws -> [RuuviCloudSensorDense] { [] }
    func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) async throws -> [AnyRuuviTagSensorRecord] { [] }
    func claim(name: String, macId: MACIdentifier) async throws -> MACIdentifier? { nil }
    func contest(macId: MACIdentifier, secret: String) async throws -> MACIdentifier? { nil }
    func unclaim(macId: MACIdentifier, removeCloudHistory: Bool) async throws -> MACIdentifier { macId }
    func share(macId: MACIdentifier, with email: String) async throws -> ShareSensorResponse {
        ShareSensorResponse()
    }
    func unshare(macId: MACIdentifier, with email: String?) async throws -> MACIdentifier { macId }
    func loadShared(for sensor: RuuviTagSensor) async throws -> Set<AnyShareableSensor> { [] }
    func checkOwner(macId: MACIdentifier) async throws -> (String?, String?) { (nil, nil) }
    func update(name: String, for sensor: RuuviTagSensor) async throws -> AnyRuuviTagSensor { sensor.any }
    func upload(
        imageData: Data,
        mimeType: MimeType,
        progress: ((MACIdentifier, Double) -> Void)?,
        for macId: MACIdentifier
    ) async throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("noop")
    }
    func resetImage(for macId: MACIdentifier) async throws {}
    func getCloudSettings() async throws -> RuuviCloudSettings? { nil }
    func set(temperatureUnit: TemperatureUnit) async throws -> TemperatureUnit { temperatureUnit }
    func set(temperatureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        temperatureAccuracy
    }
    func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit { humidityUnit }
    func set(humidityAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        humidityAccuracy
    }
    func set(pressureUnit: UnitPressure) async throws -> UnitPressure { pressureUnit }
    func set(pressureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType {
        pressureAccuracy
    }
    func set(showAllData: Bool) async throws -> Bool { showAllData }
    func set(drawDots: Bool) async throws -> Bool { drawDots }
    func set(chartDuration: Int) async throws -> Int { chartDuration }
    func set(showMinMaxAvg: Bool) async throws -> Bool { showMinMaxAvg }
    func set(cloudMode: Bool) async throws -> Bool { cloudMode }
    func set(dashboard: Bool) async throws -> Bool { dashboard }
    func set(dashboardType: DashboardType) async throws -> DashboardType { dashboardType }
    func set(dashboardTapActionType: DashboardTapActionType) async throws -> DashboardTapActionType {
        dashboardTapActionType
    }
    func set(disableEmailAlert: Bool) async throws -> Bool { disableEmailAlert }
    func set(disablePushAlert: Bool) async throws -> Bool { disablePushAlert }
    func set(marketingPreference: Bool) async throws -> Bool { marketingPreference }
    func set(profileLanguageCode: String) async throws -> String { profileLanguageCode }
    func set(dashboardSensorOrder: [String]) async throws -> [String] { dashboardSensorOrder }
    func updateSensorSettings(
        for sensor: RuuviTagSensor,
        types: [String],
        values: [String],
        timestamp: Int?
    ) async throws -> AnyRuuviTagSensor { sensor.any }
    func update(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        for sensor: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensor { sensor.any }
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
    ) async throws {}
    func loadAlerts() async throws -> [RuuviCloudSensorAlerts] { [] }
    func executeQueuedRequest(from request: RuuviCloudQueuedRequest) async throws -> Bool { true }
}
