@testable import RuuviLocal
@testable import RuuviNotifier
import Humidity
import RuuviCloud
import RuuviNotification
import RuuviOntology
import RuuviService
import XCTest

final class RuuviNotifierStatefulTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetNotifierUserDefaults()
    }

    func testProcessTemperatureAlertNotifiesObserverOnceAndSchedulesLocalAlert() {
        let sensor = makeNotifierSensor(name: "Freezer")
        let settings = makeNotifierSettings()
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(type: .temperature(lower: 0, upper: 10), ruuviTag: sensor)
        let notifications = NotificationLocalSpy()
        let observer = ObserverSpy()
        let overallTriggered = expectation(description: "overall triggered")
        let temperatureTriggered = expectation(description: "temperature triggered")
        observer.onOverall = { isTriggered, uuid in
            guard isTriggered, uuid == sensor.luid?.value else { return }
            overallTriggered.fulfill()
        }
        observer.onAlert = { type, isTriggered, uuid in
            guard isTriggered, uuid == sensor.luid?.value else { return }
            guard case .temperature = type else { return }
            temperatureTriggered.fulfill()
        }
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications
        )

        sut.subscribe(observer, to: sensor.luid!.value)
        sut.subscribe(observer, to: sensor.luid!.value)
        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                temperature: -5
            ),
            trigger: true
        )

        wait(for: [overallTriggered, temperatureTriggered], timeout: 1)
        XCTAssertTrue(sut.isSubscribed(observer, to: sensor.luid!.value))
        XCTAssertEqual(observer.overallEvents.count, 1)
        XCTAssertEqual(
            observer.alertEvents.filter { event in
                if case .temperature = event.0 {
                    return event.1 && event.2 == sensor.luid?.value
                }
                return false
            }.count,
            1
        )
        XCTAssertEqual(notifications.lowHighNotifications.count, 1)
        XCTAssertEqual(notifications.didMoveNotifications.count, 0)
        XCTAssertEqual(notifications.lowHighNotifications.first?.reason, .low)
        XCTAssertEqual(notifications.lowHighNotifications.first?.uuid, sensor.luid?.value)
        XCTAssertTrue(notifications.lowHighNotifications.first?.title.hasPrefix("low-temperature:") == true)
        if case .temperature = notifications.lowHighNotifications.first?.type {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected temperature notification")
        }
    }

    func testProcessWithTriggerDisabledStillNotifiesObserverWithoutSchedulingLocalAlert() {
        let sensor = makeNotifierSensor()
        let settings = makeNotifierSettings()
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(type: .temperature(lower: 0, upper: 10), ruuviTag: sensor)
        let notifications = NotificationLocalSpy()
        let observer = ObserverSpy()
        let overallTriggered = expectation(description: "overall triggered")
        let temperatureTriggered = expectation(description: "temperature triggered")
        observer.onOverall = { isTriggered, uuid in
            guard isTriggered, uuid == sensor.luid?.value else { return }
            overallTriggered.fulfill()
        }
        observer.onAlert = { type, isTriggered, uuid in
            guard isTriggered, uuid == sensor.luid?.value else { return }
            guard case .temperature = type else { return }
            temperatureTriggered.fulfill()
        }
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications
        )

        sut.subscribe(observer, to: sensor.luid!.value)
        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                temperature: -5
            ),
            trigger: false
        )

        wait(for: [overallTriggered, temperatureTriggered], timeout: 1)
        XCTAssertEqual(observer.overallEvents.count, 1)
        XCTAssertEqual(
            observer.alertEvents.filter { event in
                if case .temperature = event.0 {
                    return event.1 && event.2 == sensor.luid?.value
                }
                return false
            }.count,
            1
        )
        XCTAssertTrue(notifications.lowHighNotifications.isEmpty)
        XCTAssertTrue(notifications.didMoveNotifications.isEmpty)
    }

    func testMovementProcessingPersistsHysteresisAndClearsWhenAlertTurnsOff() {
        let sensor = makeNotifierSensor()
        let settings = makeNotifierSettings()
        settings.movementAlertHysteresisMinutes = 5
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(type: .movement(last: 0), ruuviTag: sensor)
        let notifications = NotificationLocalSpy()
        let observer = ObserverSpy()
        let observationCenter = NotificationCenter()
        let movementTriggered = expectation(description: "movement triggered")
        let movementCleared = expectation(description: "movement cleared")
        let didMoveNotification = expectation(description: "did move notification")
        var sawTriggeredEvent = false
        observer.onAlert = { type, isTriggered, uuid in
            guard uuid == sensor.luid?.value else { return }
            guard case .movement = type else { return }
            if isTriggered {
                sawTriggeredEvent = true
                movementTriggered.fulfill()
            } else if sawTriggeredEvent {
                movementCleared.fulfill()
            }
        }
        notifications.onDidMove = { notification in
            guard notification.uuid == sensor.luid?.value, notification.counter == 2 else { return }
            didMoveNotification.fulfill()
        }
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications,
            observationCenter: observationCenter
        )
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)

        sut.subscribe(observer, to: sensor.luid!.value)
        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                movementCounter: 1
            ),
            trigger: true
        )
        XCTAssertTrue(notifications.didMoveNotifications.isEmpty)
        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                movementCounter: 2
            ),
            trigger: true
        )

        wait(for: [movementTriggered, didMoveNotification], timeout: 1)
        XCTAssertEqual(notifications.didMoveNotifications.count, 1)
        XCTAssertEqual(alertService.movementCounter(for: physicalSensor), 2)
        XCTAssertEqual(settings.movementAlertHysteresisLastEvents().keys.sorted(), [sensor.luid!.value])
        alertService.unregister(type: .movement(last: 0), ruuviTag: sensor)

        observationCenter.post(
            name: .RuuviServiceAlertDidChange,
            object: nil,
            userInfo: [
                RuuviServiceAlertDidChangeKey.type: AlertType.movement(last: 0),
                RuuviServiceAlertDidChangeKey.physicalSensor: physicalSensor,
            ]
        )

        wait(for: [movementCleared], timeout: 1)
        XCTAssertTrue(settings.movementAlertHysteresisLastEvents().isEmpty)
    }

    func testInitRestoresMovementHysteresisByDroppingExpiredAndDisabledEntries() {
        let settings = makeNotifierSettings()
        settings.movementAlertHysteresisMinutes = 5
        settings.setMovementAlertHysteresisLastEvents([
            "active-luid": Date().addingTimeInterval(-60),
            "expired-luid": Date().addingTimeInterval(-600),
            "disabled-luid": Date().addingTimeInterval(-60),
        ])
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(
            type: .movement(last: 0),
            ruuviTag: makeNotifierSensor(luid: "active-luid", macId: nil)
        )

        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: NotificationLocalSpy()
        )

        XCTAssertEqual(sut.movementAlertHysteresisLastEventByUUID.keys.sorted(), ["active-luid"])
        XCTAssertEqual(settings.movementAlertHysteresisLastEvents().keys.sorted(), ["active-luid"])
    }

    func testProcessNetworkCloudConnectionUsesRecentSyncThreshold() {
        let sensor = makeNotifierSensor(luid: nil, macId: "AA:BB:CC:11:22:33")
        let settings = makeNotifierSettings()
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(type: .cloudConnection(unseenDuration: 60), ruuviTag: sensor)
        let notifications = NotificationLocalSpy()
        let syncState = RuuviLocalSyncStateUserDefaults()
        syncState.setSyncDate(Date())
        let observer = ObserverSpy()
        let overallTriggered = expectation(description: "overall triggered")
        let cloudTriggered = expectation(description: "cloud triggered")
        observer.onOverall = { isTriggered, uuid in
            guard isTriggered, uuid == sensor.macId?.value else { return }
            overallTriggered.fulfill()
        }
        observer.onAlert = { type, isTriggered, uuid in
            guard isTriggered, uuid == sensor.macId?.value else { return }
            guard case .cloudConnection = type else { return }
            cloudTriggered.fulfill()
        }
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications,
            syncState: syncState
        )

        sut.subscribe(observer, to: sensor.macId!.value)
        sut.processNetwork(
            record: makeNotifierRecord(
                luid: nil,
                macId: sensor.macId?.value,
                date: Date().addingTimeInterval(-120)
            ),
            trigger: true,
            for: sensor.macId!
        )

        wait(for: [overallTriggered, cloudTriggered], timeout: 1)
        XCTAssertTrue(notifications.lowHighNotifications.isEmpty)
        XCTAssertTrue(notifications.didMoveNotifications.isEmpty)
    }

    func testProcessCoversAdditionalPhysicalAlertBranches() {
        let sensor = makeNotifierSensor()
        let settings = makeNotifierSettings()
        let alertService = makeNotifierAlertService(settings: settings)
        let notifications = NotificationLocalSpy()
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications
        )
        let registeredAlerts: [AlertType] = [
            .temperature(lower: 0, upper: 10),
            .relativeHumidity(lower: 0.3, upper: 0.5),
            .humidity(
                lower: Humidity(value: 4, unit: .absolute),
                upper: Humidity(value: 6, unit: .absolute)
            ),
            .dewPoint(lower: 0, upper: 10),
            .pressure(lower: 1000, upper: 1100),
            .signal(lower: -80, upper: -40),
            .batteryVoltage(lower: 2.4, upper: 3.1),
            .aqi(lower: 80, upper: 100),
            .carbonDioxide(lower: 0, upper: 500),
            .pMatter1(lower: 0, upper: 10),
            .pMatter25(lower: 0, upper: 12),
            .pMatter4(lower: 0, upper: 15),
            .pMatter10(lower: 0, upper: 20),
            .voc(lower: 0, upper: 100),
            .nox(lower: 0, upper: 100),
            .soundAverage(lower: 0, upper: 55),
            .soundPeak(lower: 0, upper: 70),
            .luminosity(lower: 0, upper: 100),
        ]
        for alert in registeredAlerts {
            alertService.register(type: alert, ruuviTag: sensor)
        }
        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                temperature: -5,
                humidity: 0.9,
                pressure: 1200,
                voltage: 2.0,
                rssi: -90,
                co2: 600,
                pm25: 30,
                pm1: 20,
                pm4: 40,
                pm10: 50,
                voc: 200,
                nox: 200,
                luminance: 200,
                dbaInstant: 70,
                dbaAvg: 65,
                dbaPeak: 80
            ),
            trigger: true
        )

        waitUntil(timeout: 3) {
            notifications.lowHighNotifications.count == registeredAlerts.count
        }
        XCTAssertEqual(notifications.lowHighNotifications.count, registeredAlerts.count)
        XCTAssertEqual(
            Set(notifications.lowHighNotifications.map { $0.type.rawValue }),
            Set(registeredAlerts.map { normalizedAlertType(for: $0).rawValue })
        )
    }

    func testProcessCoversComplementaryLowBranchesForPhysicalAlerts() {
        let sensor = makeNotifierSensor()
        let settings = makeNotifierSettings()
        let alertService = makeNotifierAlertService(settings: settings)
        let notifications = NotificationLocalSpy()
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications
        )
        let registeredAlerts: [AlertType] = [
            .temperature(lower: 20, upper: 30),
            .relativeHumidity(lower: 0.5, upper: 0.7),
            .humidity(
                lower: Humidity(value: 8, unit: .absolute),
                upper: Humidity(value: 12, unit: .absolute)
            ),
            .dewPoint(lower: 10, upper: 20),
            .pressure(lower: 1010, upper: 1100),
            .signal(lower: -60, upper: -40),
            .batteryVoltage(lower: 2.5, upper: 3.2),
            .aqi(lower: 90, upper: 100),
            .carbonDioxide(lower: 700, upper: 800),
            .pMatter1(lower: 30, upper: 40),
            .pMatter25(lower: 35, upper: 40),
            .pMatter4(lower: 45, upper: 50),
            .pMatter10(lower: 55, upper: 60),
            .voc(lower: 300, upper: 400),
            .nox(lower: 250, upper: 300),
            .soundInstant(lower: 80, upper: 90),
            .soundAverage(lower: 75, upper: 80),
            .soundPeak(lower: 90, upper: 100),
            .luminosity(lower: 300, upper: 400),
        ]
        for alert in registeredAlerts {
            alertService.register(type: alert, ruuviTag: sensor)
        }

        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                temperature: 5,
                humidity: 0.2,
                pressure: 900,
                voltage: 2.0,
                rssi: -90,
                co2: 600,
                pm25: 30,
                pm1: 20,
                pm4: 40,
                pm10: 50,
                voc: 200,
                nox: 200,
                luminance: 200,
                dbaInstant: 70,
                dbaAvg: 65,
                dbaPeak: 80
            ),
            trigger: true
        )

        waitUntil(timeout: 3) {
            notifications.lowHighNotifications.count == registeredAlerts.count
        }
        XCTAssertEqual(notifications.lowHighNotifications.count, registeredAlerts.count)
        XCTAssertEqual(Set(notifications.lowHighNotifications.map(\.reason)), [.low])
        XCTAssertEqual(
            Set(notifications.lowHighNotifications.map { $0.type.rawValue }),
            Set(registeredAlerts.map { normalizedAlertType(for: $0).rawValue })
        )
    }

    func testProcessCoversHighBranchesForScalarAlerts() {
        let sensor = makeNotifierSensor()
        let settings = makeNotifierSettings()
        let alertService = makeNotifierAlertService(settings: settings)
        let notifications = NotificationLocalSpy()
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications
        )
        let registeredAlerts: [AlertType] = [
            .temperature(lower: 0, upper: 10),
            .humidity(
                lower: .zeroAbsolute,
                upper: Humidity(value: 1, unit: .absolute)
            ),
            .dewPoint(lower: 0, upper: 10),
            .signal(lower: -80, upper: -40),
            .batteryVoltage(lower: 2.0, upper: 3.0),
            .aqi(lower: 0, upper: 90),
        ]
        for alert in registeredAlerts {
            alertService.register(type: alert, ruuviTag: sensor)
        }

        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                temperature: 40,
                humidity: 0.9,
                voltage: 4.0,
                rssi: -20,
                co2: 420,
                pm25: 0
            ),
            trigger: true
        )

        waitUntil(timeout: 3) {
            notifications.lowHighNotifications.count == registeredAlerts.count
        }
        XCTAssertEqual(notifications.lowHighNotifications.count, registeredAlerts.count)
        XCTAssertEqual(Set(notifications.lowHighNotifications.map(\.reason)), [.high])
        XCTAssertEqual(
            Set(notifications.lowHighNotifications.map { $0.type.rawValue }),
            Set(registeredAlerts.map { normalizedAlertType(for: $0).rawValue })
        )
    }

    func testSubscriptionReportsFalseForMissingOrDifferentObservers() {
        let sensor = makeNotifierSensor()
        let sut = makeNotifier(notifications: NotificationLocalSpy())
        let subscribedObserver = ObserverSpy()
        let otherObserver = ObserverSpy()
        let uuid = sensor.luid!.value

        XCTAssertFalse(sut.isSubscribed(subscribedObserver, to: uuid))

        sut.subscribe(subscribedObserver, to: uuid)

        XCTAssertTrue(sut.isSubscribed(subscribedObserver, to: uuid))
        XCTAssertFalse(sut.isSubscribed(otherObserver, to: uuid))
        XCTAssertFalse(sut.isSubscribed(subscribedObserver, to: "other-luid"))
    }

    func testSubscribeAddsDifferentObserversToExistingSubscriptionArray() {
        let uuid = "shared-luid"
        let sut = makeNotifier(notifications: NotificationLocalSpy())
        let firstObserver = ObserverSpy()
        let secondObserver = ObserverSpy()

        sut.subscribe(firstObserver, to: uuid)
        sut.subscribe(secondObserver, to: uuid)

        XCTAssertTrue(sut.isSubscribed(firstObserver, to: uuid))
        XCTAssertTrue(sut.isSubscribed(secondObserver, to: uuid))
        XCTAssertEqual(sut.observations[uuid]?.count, 2)
    }

    func testProcessGuardsMissingRegistrationsAndMissingHumiditySpecificAlerts() {
        let sensor = makeNotifierSensor()
        let settings = makeNotifierSettings()
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(type: .temperature(lower: 0, upper: 10), ruuviTag: sensor)
        let notifications = NotificationLocalSpy()
        let observer = ObserverSpy()
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications
        )

        sut.subscribe(observer, to: sensor.luid!.value)
        sut.process(
            record: makeNotifierRecord(
                luid: nil,
                macId: sensor.macId?.value,
                temperature: -5
            ),
            trigger: true
        )
        sut.processNetwork(
            record: makeNotifierRecord(
                luid: nil,
                macId: "AA:BB:CC:44:55:66",
                temperature: -5
            ),
            trigger: true,
            for: "AA:BB:CC:44:55:66".mac
        )
        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                temperature: 20,
                humidity: 0.5
            ),
            trigger: false
        )

        XCTAssertTrue(notifications.lowHighNotifications.isEmpty)
        XCTAssertEqual(
            observer.alertEvents.filter { event in
                event.0.rawValue == AlertType.humidity(
                    lower: .zeroAbsolute,
                    upper: .zeroAbsolute
                ).rawValue && event.1
            }.count,
            0
        )
        XCTAssertEqual(
            observer.alertEvents.filter { event in
                event.0.rawValue == AlertType.dewPoint(lower: 0, upper: 0).rawValue && event.1
            }.count,
            0
        )
    }

    func testAlertChangeObserverIgnoresMalformedAndIdentifierlessNotifications() {
        let settings = makeNotifierSettings()
        settings.setMovementAlertHysteresisLastEvents([
            "keep-luid": Date()
        ])
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(
            type: .movement(last: 0),
            ruuviTag: makeNotifierSensor(luid: "keep-luid", macId: nil)
        )
        let observationCenter = NotificationCenter()
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: NotificationLocalSpy(),
            observationCenter: observationCenter
        )

        sut.handleAlertDidChange(userInfo: nil)
        sut.handleAlertDidChange(userInfo: [
            RuuviServiceAlertDidChangeKey.type: AlertType.movement(last: 0),
            RuuviServiceAlertDidChangeKey.physicalSensor: PhysicalSensorStruct(luid: nil, macId: nil),
        ])
        observationCenter.post(
            name: .RuuviServiceAlertDidChange,
            object: nil,
            userInfo: nil
        )
        observationCenter.post(
            name: .RuuviServiceAlertDidChange,
            object: nil,
            userInfo: [
                RuuviServiceAlertDidChangeKey.type: AlertType.movement(last: 0),
                RuuviServiceAlertDidChangeKey.physicalSensor: PhysicalSensorStruct(luid: nil, macId: nil),
            ]
        )

        waitUntil(timeout: 0.2) { false }
        XCTAssertEqual(settings.movementAlertHysteresisLastEvents().keys.sorted(), ["keep-luid"])
    }

    func testMovementWithoutCounterUsesActiveAndExpiredHysteresisState() {
        let sensor = makeNotifierSensor()
        let settings = makeNotifierSettings()
        settings.movementAlertHysteresisMinutes = 5
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(type: .movement(last: 0), ruuviTag: sensor)
        let observer = ObserverSpy()
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: NotificationLocalSpy()
        )

        sut.subscribe(observer, to: sensor.luid!.value)
        sut.movementAlertHysteresisLastEventByUUID[sensor.luid!.value] = Date()
        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                movementCounter: nil
            ),
            trigger: true
        )

        sut.movementAlertHysteresisLastEventByUUID[sensor.luid!.value] = Date().addingTimeInterval(-600)
        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                movementCounter: nil
            ),
            trigger: true
        )

        waitUntil(timeout: 1) {
            observer.alertEvents.contains { event in
                if case .movement = event.0 {
                    return event.1 && event.2 == sensor.luid?.value
                }
                return false
            } && observer.alertEvents.contains { event in
                if case .movement = event.0 {
                    return !event.1 && event.2 == sensor.luid?.value
                }
                return false
            }
        }
        XCTAssertTrue(observer.alertEvents.contains { event in
            if case .movement = event.0 {
                return event.1 && event.2 == sensor.luid?.value
            }
            return false
        })
        XCTAssertTrue(observer.alertEvents.contains { event in
            if case .movement = event.0 {
                return !event.1 && event.2 == sensor.luid?.value
            }
            return false
        })
        XCTAssertTrue(settings.movementAlertHysteresisLastEvents().isEmpty)
    }

    func testMovementHysteresisZeroIntervalClearsStoredEventsAcrossBranches() {
        let sensor = makeNotifierSensor()
        let settings = makeNotifierSettings()
        settings.movementAlertHysteresisMinutes = 0
        settings.setMovementAlertHysteresisLastEvents([
            sensor.luid!.value: Date()
        ])
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(type: .movement(last: 0), ruuviTag: sensor)
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: NotificationLocalSpy()
        )

        XCTAssertTrue(settings.movementAlertHysteresisLastEvents().isEmpty)

        sut.movementAlertHysteresisLastEventByUUID[sensor.luid!.value] = Date()
        settings.setMovementAlertHysteresisLastEvents([
            sensor.luid!.value: Date()
        ])
        alertService.setMovement(
            counter: 1,
            for: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                movementCounter: 1
            )
        )
        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                movementCounter: 2
            ),
            trigger: true
        )
        XCTAssertTrue(settings.movementAlertHysteresisLastEvents().isEmpty)

        sut.movementAlertHysteresisLastEventByUUID[sensor.luid!.value] = Date()
        settings.setMovementAlertHysteresisLastEvents([
            sensor.luid!.value: Date()
        ])
        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                movementCounter: nil
            ),
            trigger: true
        )

        XCTAssertTrue(settings.movementAlertHysteresisLastEvents().isEmpty)
    }

    func testMovementHysteresisIgnoresOlderEventWhenFutureEventExists() {
        let sensor = makeNotifierSensor()
        let settings = makeNotifierSettings()
        settings.movementAlertHysteresisMinutes = 5
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(type: .movement(last: 0), ruuviTag: sensor)
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: NotificationLocalSpy()
        )
        let futureEvent = Date().addingTimeInterval(120)

        sut.movementAlertHysteresisLastEventByUUID[sensor.luid!.value] = futureEvent
        alertService.setMovement(
            counter: 1,
            for: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                movementCounter: 1
            )
        )
        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                date: Date(),
                movementCounter: 2
            ),
            trigger: true
        )

        XCTAssertEqual(sut.movementAlertHysteresisLastEventByUUID[sensor.luid!.value], futureEvent)
    }

    func testMovementHysteresisTimerHandlerExpiresEntriesAndClearsZeroIntervalState() {
        let expiredSensor = makeNotifierSensor(luid: "expired-luid", macId: nil)
        let activeSensor = makeNotifierSensor(luid: "active-luid", macId: nil)
        let settings = makeNotifierSettings()
        settings.movementAlertHysteresisMinutes = 5
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(type: .movement(last: 0), ruuviTag: expiredSensor)
        alertService.register(type: .movement(last: 0), ruuviTag: activeSensor)
        let observer = ObserverSpy()
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: NotificationLocalSpy()
        )

        sut.subscribe(observer, to: expiredSensor.luid!.value)
        sut.movementAlertHysteresisLastEventByUUID = [
            expiredSensor.luid!.value: Date().addingTimeInterval(-600),
            activeSensor.luid!.value: Date(),
        ]
        sut.handleMovementHysteresisTimerFired()

        waitUntil(timeout: 1) {
            observer.alertEvents.contains { event in
                if case .movement = event.0 {
                    return !event.1 && event.2 == expiredSensor.luid?.value
                }
                return false
            }
        }
        XCTAssertEqual(sut.movementAlertHysteresisLastEventByUUID.keys.sorted(), [activeSensor.luid!.value])
        XCTAssertTrue(observer.alertEvents.contains { event in
            if case .movement = event.0 {
                return !event.1 && event.2 == expiredSensor.luid?.value
            }
            return false
        })

        settings.movementAlertHysteresisMinutes = 0
        sut.movementAlertHysteresisLastEventByUUID = [
            activeSensor.luid!.value: Date()
        ]
        sut.handleMovementHysteresisTimerFired()

        XCTAssertTrue(sut.movementAlertHysteresisLastEventByUUID.isEmpty)
    }

    func testProcessNetworkCloudConnectionDoesNotTriggerWhenSystemSyncIsTooOld() {
        let sensor = makeNotifierSensor(luid: nil, macId: "AA:BB:CC:11:22:33")
        let settings = makeNotifierSettings()
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(type: .cloudConnection(unseenDuration: 60), ruuviTag: sensor)
        let syncState = RuuviLocalSyncStateUserDefaults()
        syncState.setSyncDate(Date().addingTimeInterval(-3600))
        let observer = ObserverSpy()
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: NotificationLocalSpy(),
            syncState: syncState
        )

        sut.subscribe(observer, to: sensor.macId!.value)
        sut.processNetwork(
            record: makeNotifierRecord(
                luid: nil,
                macId: sensor.macId?.value,
                date: Date().addingTimeInterval(-3600)
            ),
            trigger: true,
            for: sensor.macId!
        )

        waitUntil(timeout: 1) {
            observer.alertEvents.contains { event in
                if case .cloudConnection = event.0 {
                    return !event.1 && event.2 == sensor.macId?.value
                }
                return false
            } && observer.overallEvents.contains { event in
                !event.0 && event.1 == sensor.macId?.value
            }
        }
        XCTAssertTrue(observer.alertEvents.contains { event in
            if case .cloudConnection = event.0 {
                return !event.1 && event.2 == sensor.macId?.value
            }
            return false
        })
        XCTAssertTrue(observer.overallEvents.contains { event in
            !event.0 && event.1 == sensor.macId?.value
        })
    }

    func testProcessNetworkUsesMacIdentifierForMacOnlyScalarAlerts() {
        let sensor = makeNotifierSensor(luid: nil, macId: "AA:BB:CC:11:22:33")
        let settings = makeNotifierSettings()
        let alertService = makeNotifierAlertService(settings: settings)
        let notifications = NotificationLocalSpy()
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications
        )
        let registeredAlerts: [AlertType] = [
            .aqi(lower: 80, upper: 100),
            .carbonDioxide(lower: 0, upper: 500),
            .pMatter1(lower: 0, upper: 10),
            .pMatter25(lower: 0, upper: 12),
            .pMatter4(lower: 0, upper: 15),
            .pMatter10(lower: 0, upper: 20),
            .voc(lower: 0, upper: 100),
            .nox(lower: 0, upper: 100),
            .soundAverage(lower: 0, upper: 55),
            .soundPeak(lower: 0, upper: 70),
            .luminosity(lower: 0, upper: 100),
        ]
        for alert in registeredAlerts {
            alertService.register(type: alert, ruuviTag: sensor)
        }
        sut.processNetwork(
            record: makeNotifierRecord(
                luid: nil,
                macId: sensor.macId?.value,
                co2: 600,
                pm25: 30,
                pm1: 20,
                pm4: 40,
                pm10: 50,
                voc: 200,
                nox: 200,
                luminance: 200,
                dbaInstant: 70,
                dbaAvg: 65,
                dbaPeak: 80
            ),
            trigger: true,
            for: sensor.macId!
        )

        waitUntil(timeout: 3) {
            notifications.lowHighNotifications.count == registeredAlerts.count
        }
        XCTAssertEqual(notifications.lowHighNotifications.count, registeredAlerts.count)
        XCTAssertEqual(
            Set(notifications.lowHighNotifications.map { $0.type.rawValue }),
            Set(registeredAlerts.map { normalizedAlertType(for: $0).rawValue })
        )
        XCTAssertEqual(Set(notifications.lowHighNotifications.map(\.uuid)), [sensor.macId!.value])
    }

    func testProcessNetworkUsesMacIdentifierForComplementaryLowScalarAlerts() {
        let sensor = makeNotifierSensor(luid: nil, macId: "AA:BB:CC:11:22:33")
        let settings = makeNotifierSettings()
        let alertService = makeNotifierAlertService(settings: settings)
        let notifications = NotificationLocalSpy()
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications
        )
        let registeredAlerts: [AlertType] = [
            .aqi(lower: 90, upper: 100),
            .carbonDioxide(lower: 700, upper: 800),
            .pMatter1(lower: 30, upper: 40),
            .pMatter25(lower: 35, upper: 40),
            .pMatter4(lower: 45, upper: 50),
            .pMatter10(lower: 55, upper: 60),
            .voc(lower: 300, upper: 400),
            .nox(lower: 250, upper: 300),
            .soundInstant(lower: 80, upper: 90),
            .soundAverage(lower: 75, upper: 80),
            .soundPeak(lower: 90, upper: 100),
            .luminosity(lower: 300, upper: 400),
        ]
        for alert in registeredAlerts {
            alertService.register(type: alert, ruuviTag: sensor)
        }

        sut.processNetwork(
            record: makeNotifierRecord(
                luid: nil,
                macId: sensor.macId?.value,
                co2: 600,
                pm25: 30,
                pm1: 20,
                pm4: 40,
                pm10: 50,
                voc: 200,
                nox: 200,
                luminance: 200,
                dbaInstant: 70,
                dbaAvg: 65,
                dbaPeak: 80
            ),
            trigger: true,
            for: sensor.macId!
        )

        waitUntil(timeout: 3) {
            notifications.lowHighNotifications.count == registeredAlerts.count
        }
        XCTAssertEqual(notifications.lowHighNotifications.count, registeredAlerts.count)
        XCTAssertEqual(Set(notifications.lowHighNotifications.map(\.reason)), [.low])
        XCTAssertEqual(Set(notifications.lowHighNotifications.map(\.uuid)), [sensor.macId!.value])
    }

    func testProcessSoundInstantAlertSchedulesNotification() {
        let sensor = makeNotifierSensor()
        let settings = makeNotifierSettings()
        let alertService = makeNotifierAlertService(settings: settings)
        let notifications = NotificationLocalSpy()
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications
        )
        alertService.register(type: .soundInstant(lower: 0, upper: 60), ruuviTag: sensor)
        XCTAssertNotNil(
            alertService.alert(
                for: sensor.luid!.value,
                of: .soundInstant(lower: 0, upper: 0)
            )
        )

        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                dbaInstant: 70
            ),
            trigger: true
        )

        waitUntil(timeout: 1) {
            notifications.lowHighNotifications.count == 1
        }
        XCTAssertEqual(notifications.lowHighNotifications.map(\.type.rawValue), ["soundInstant"])
        XCTAssertEqual(notifications.lowHighNotifications.map(\.uuid), [sensor.luid!.value])
    }

    func testProcessNetworkSoundInstantAlertUsesMacIdentifier() {
        let sensor = makeNotifierSensor(luid: nil, macId: "AA:BB:CC:11:22:33")
        let settings = makeNotifierSettings()
        let alertService = makeNotifierAlertService(settings: settings)
        let notifications = NotificationLocalSpy()
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications
        )
        alertService.register(type: .soundInstant(lower: 0, upper: 60), ruuviTag: sensor)
        XCTAssertNotNil(
            alertService.alert(
                for: sensor.macId!.value,
                of: .soundInstant(lower: 0, upper: 0)
            )
        )

        sut.processNetwork(
            record: makeNotifierRecord(
                luid: nil,
                macId: sensor.macId?.value,
                dbaInstant: 70
            ),
            trigger: true,
            for: sensor.macId!
        )

        waitUntil(timeout: 1) {
            notifications.lowHighNotifications.count == 1
        }
        XCTAssertEqual(notifications.lowHighNotifications.map(\.type.rawValue), ["soundInstant"])
        XCTAssertEqual(notifications.lowHighNotifications.map(\.uuid), [sensor.macId!.value])
    }

    func testMovementHysteresisTimerFireClearsExpiredEntryAndNotifiesObserver() {
        let sensor = makeNotifierSensor()
        let settings = makeNotifierSettings()
        settings.movementAlertHysteresisMinutes = 5
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(type: .movement(last: 0), ruuviTag: sensor)
        let notifications = NotificationLocalSpy()
        let observer = ObserverSpy()
        let cleared = expectation(description: "movement cleared by timer")
        observer.onAlert = { type, isTriggered, uuid in
            guard uuid == sensor.luid?.value else { return }
            guard case .movement = type, !isTriggered else { return }
            cleared.fulfill()
        }
        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications
        )

        sut.subscribe(observer, to: sensor.luid!.value)
        sut.process(
            record: makeNotifierRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                date: Date(),
                movementCounter: 1
            ),
            trigger: true
        )

        waitUntil(timeout: 1) {
            sut.movementAlertHysteresisTimer != nil
        }
        sut.movementAlertHysteresisLock.lock()
        sut.movementAlertHysteresisLastEventByUUID[sensor.luid!.value] = Date().addingTimeInterval(-600)
        sut.movementAlertHysteresisLock.unlock()
        sut.movementAlertHysteresisTimer?.fire()

        wait(for: [cleared], timeout: 1)
        XCTAssertTrue(settings.movementAlertHysteresisLastEvents().isEmpty)
    }

    func testScheduledMovementHysteresisTimerExpiresRestoredEntryAndNotifiesObserver() {
        let sensor = makeNotifierSensor(luid: "scheduled-luid", macId: nil)
        let settings = makeNotifierSettings()
        settings.movementAlertHysteresisMinutes = 1
        settings.setMovementAlertHysteresisLastEvents([
            sensor.luid!.value: Date().addingTimeInterval(-58)
        ])
        let alertService = makeNotifierAlertService(settings: settings)
        alertService.register(type: .movement(last: 0), ruuviTag: sensor)
        let notifications = NotificationLocalSpy()
        let observer = ObserverSpy()
        let cleared = expectation(description: "movement cleared by scheduled timer")
        observer.onAlert = { type, isTriggered, uuid in
            guard uuid == sensor.luid?.value else { return }
            guard case .movement = type, !isTriggered else { return }
            cleared.fulfill()
        }

        let sut = makeNotifier(
            settings: settings,
            alertService: alertService,
            notifications: notifications
        )

        sut.subscribe(observer, to: sensor.luid!.value)
        waitUntil(timeout: 1) {
            sut.movementAlertHysteresisTimer != nil
        }

        wait(for: [cleared], timeout: 4)
        XCTAssertTrue(settings.movementAlertHysteresisLastEvents().isEmpty)
    }

    func testPublicConvenienceInitializerAndMacOnlyMovementAlertChangeHandling() {
        let settings = makeNotifierSettings()
        settings.movementAlertHysteresisMinutes = 5
        settings.setMovementAlertHysteresisLastEvents([
            "AA:BB:CC:11:22:33": Date()
        ])
        let alertService = makeNotifierAlertService(settings: settings)
        let notifications = NotificationLocalSpy()
        let measurementService = RuuviServiceMeasurementImpl(
            settings: settings,
            emptyValueString: "-",
            percentString: "%"
        )
        let observer = ObserverSpy()
        let cleared = expectation(description: "movement cleared for mac sensor")
        var didClear = false
        observer.onAlert = { type, isTriggered, uuid in
            guard uuid == "AA:BB:CC:11:22:33" else { return }
            guard case .movement = type, !isTriggered else { return }
            guard !didClear else { return }
            didClear = true
            cleared.fulfill()
        }
        let sut = RuuviNotifierImpl(
            ruuviAlertService: alertService,
            ruuviNotificationLocal: notifications,
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            measurementService: measurementService,
            settings: settings,
            titles: TitlesStub()
        )
        let alertSensor = makeNotifierSensor(luid: nil, macId: "AA:BB:CC:11:22:33")
        let physicalSensor = PhysicalSensorStruct(luid: nil, macId: "AA:BB:CC:11:22:33".mac)
        alertService.register(type: .movement(last: 0), ruuviTag: alertSensor)

        sut.subscribe(observer, to: "AA:BB:CC:11:22:33")
        XCTAssertTrue(sut.isSubscribed(observer, to: "AA:BB:CC:11:22:33"))
        alertService.unregister(type: .movement(last: 0), ruuviTag: alertSensor)
        NotificationCenter.default.post(
            name: .RuuviServiceAlertDidChange,
            object: nil,
            userInfo: [
                RuuviServiceAlertDidChangeKey.type: AlertType.movement(last: 0),
                RuuviServiceAlertDidChangeKey.physicalSensor: physicalSensor,
            ]
        )

        wait(for: [cleared], timeout: 1)
        XCTAssertTrue(settings.movementAlertHysteresisLastEvents().isEmpty)
    }
}

private func makeNotifier(
    settings: RuuviLocalSettingsUserDefaults = makeNotifierSettings(),
    alertService: RuuviServiceAlertImpl? = nil,
    notifications: NotificationLocalSpy,
    syncState: RuuviLocalSyncState = RuuviLocalSyncStateUserDefaults(),
    observationCenter: NotificationCenter = NotificationCenter()
) -> RuuviNotifierImpl {
    let resolvedAlertService = alertService ?? makeNotifierAlertService(settings: settings)
    return RuuviNotifierImpl(
        ruuviAlertService: resolvedAlertService,
        ruuviNotificationLocal: notifications,
        localSyncState: syncState,
        measurementService: RuuviServiceMeasurementImpl(
            settings: settings,
            emptyValueString: "-",
            percentString: "%"
        ),
        settings: settings,
        titles: TitlesStub(),
        observationCenter: observationCenter
    )
}

private func makeNotifierAlertService(
    settings: RuuviLocalSettingsUserDefaults
) -> RuuviServiceAlertImpl {
    RuuviServiceAlertImpl(
        cloud: NoOpCloud(),
        localIDs: RuuviLocalIDsUserDefaults(),
        ruuviLocalSettings: settings
    )
}

private func makeNotifierSettings() -> RuuviLocalSettingsUserDefaults {
    let settings = RuuviLocalSettingsUserDefaults()
    settings.temperatureUnit = .celsius
    settings.temperatureAccuracy = .two
    settings.humidityUnit = .percent
    settings.humidityAccuracy = .two
    settings.pressureUnit = .hectopascals
    settings.pressureAccuracy = .two
    settings.language = .english
    settings.movementAlertHysteresisMinutes = 5
    settings.setMovementAlertHysteresisLastEvents([:])
    return settings
}

private func makeNotifierSensor(
    luid: String? = "luid-1",
    macId: String? = "AA:BB:CC:11:22:33",
    name: String = "Sensor"
) -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: 5,
        firmwareVersion: "1.0.0",
        luid: luid?.luid,
        macId: macId?.mac,
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

private func makeNotifierRecord(
    luid: String? = "luid-1",
    macId: String? = "AA:BB:CC:11:22:33",
    date: Date = Date(),
    temperature: Double? = nil,
    humidity: Double? = nil,
    pressure: Double? = nil,
    voltage: Double? = nil,
    movementCounter: Int? = nil,
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
        source: .advertisement,
        macId: macId?.mac,
        rssi: rssi,
        version: 5,
        temperature: temperature.map { Temperature(value: $0, unit: .celsius) },
        humidity: humidity.map {
            Humidity(
                value: $0,
                unit: .relative(
                    temperature: Temperature(value: temperature ?? 20, unit: .celsius)
                )
            )
        },
        pressure: pressure.map { Pressure(value: $0, unit: .hectopascals) },
        acceleration: nil,
        voltage: voltage.map { Voltage(value: $0, unit: .volts) },
        movementCounter: movementCounter,
        measurementSequenceNumber: nil,
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

private func resetNotifierUserDefaults() {
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

private func normalizedAlertType(for type: AlertType) -> AlertType {
    AlertType.alertType(from: type.rawValue) ?? type
}

private final class NotificationLocalSpy: RuuviNotificationLocal {
    struct LowHighCall {
        let reason: LowHighNotificationReason
        let type: AlertType
        let uuid: String
        let title: String
    }

    struct DidMoveCall {
        let uuid: String
        let counter: Int
        let title: String
    }

    var lowHighNotifications: [LowHighCall] = []
    var didMoveNotifications: [DidMoveCall] = []
    var onDidMove: ((DidMoveCall) -> Void)?

    func setup(
        disableTitle _: String,
        muteTitle _: String,
        output _: RuuviNotificationLocalOutput?
    ) {}

    func showDidConnect(uuid _: String, title _: String) {}
    func showDidDisconnect(uuid _: String, title _: String) {}

    func notifyDidMove(for uuid: String, counter: Int, title: String) {
        let call = DidMoveCall(uuid: uuid, counter: counter, title: title)
        didMoveNotifications.append(call)
        onDidMove?(call)
    }

    func notify(
        _ reason: LowHighNotificationReason,
        _ type: AlertType,
        for uuid: String,
        title: String
    ) {
        lowHighNotifications.append(LowHighCall(reason: reason, type: type, uuid: uuid, title: title))
    }
}

private final class ObserverSpy: RuuviNotifierObserver {
    var overallEvents: [(Bool, String)] = []
    var alertEvents: [(AlertType, Bool, String)] = []
    var onOverall: ((Bool, String) -> Void)?
    var onAlert: ((AlertType, Bool, String) -> Void)?

    func ruuvi(notifier _: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        overallEvents.append((isTriggered, uuid))
        onOverall?(isTriggered, uuid)
    }

    func ruuvi(
        notifier _: RuuviNotifier,
        alertType: AlertType,
        isTriggered: Bool,
        for uuid: String
    ) {
        alertEvents.append((alertType, isTriggered, uuid))
        onAlert?(alertType, isTriggered, uuid)
    }
}

private struct TitlesStub: RuuviNotifierTitles {
    let didMove = "did-move"

    func lowTemperature(_ value: String) -> String { title("low-temperature", value) }
    func highTemperature(_ value: String) -> String { title("high-temperature", value) }
    func lowHumidity(_ value: String) -> String { title("low-humidity", value) }
    func highHumidity(_ value: String) -> String { title("high-humidity", value) }
    func lowAbsoluteHumidity(_ value: String) -> String { title("low-absolute-humidity", value) }
    func highAbsoluteHumidity(_ value: String) -> String { title("high-absolute-humidity", value) }
    func lowDewPoint(_ value: String) -> String { title("low-dew-point", value) }
    func highDewPoint(_ value: String) -> String { title("high-dew-point", value) }
    func lowPressure(_ value: String) -> String { title("low-pressure", value) }
    func highPressure(_ value: String) -> String { title("high-pressure", value) }
    func lowSignal(_ value: String) -> String { title("low-signal", value) }
    func highSignal(_ value: String) -> String { title("high-signal", value) }
    func lowAQI(_ value: String) -> String { title("low-aqi", value) }
    func highAQI(_ value: String) -> String { title("high-aqi", value) }
    func lowCarbonDioxide(_ value: String) -> String { title("low-co2", value) }
    func highCarbonDioxide(_ value: String) -> String { title("high-co2", value) }
    func lowPMatter1(_ value: String) -> String { title("low-pm1", value) }
    func highPMatter1(_ value: String) -> String { title("high-pm1", value) }
    func lowPMatter25(_ value: String) -> String { title("low-pm25", value) }
    func highPMatter25(_ value: String) -> String { title("high-pm25", value) }
    func lowPMatter4(_ value: String) -> String { title("low-pm4", value) }
    func highPMatter4(_ value: String) -> String { title("high-pm4", value) }
    func lowPMatter10(_ value: String) -> String { title("low-pm10", value) }
    func highPMatter10(_ value: String) -> String { title("high-pm10", value) }
    func lowVOC(_ value: String) -> String { title("low-voc", value) }
    func highVOC(_ value: String) -> String { title("high-voc", value) }
    func lowNOx(_ value: String) -> String { title("low-nox", value) }
    func highNOx(_ value: String) -> String { title("high-nox", value) }
    func lowSoundInstant(_ value: String) -> String { title("low-sound-instant", value) }
    func highSoundInstant(_ value: String) -> String { title("high-sound-instant", value) }
    func lowSoundAverage(_ value: String) -> String { title("low-sound-average", value) }
    func highSoundAverage(_ value: String) -> String { title("high-sound-average", value) }
    func lowSoundPeak(_ value: String) -> String { title("low-sound-peak", value) }
    func highSoundPeak(_ value: String) -> String { title("high-sound-peak", value) }
    func lowLuminosity(_ value: String) -> String { title("low-luminosity", value) }
    func highLuminosity(_ value: String) -> String { title("high-luminosity", value) }
    func lowBatteryVoltage(_ value: String) -> String { title("low-battery-voltage", value) }
    func highBatteryVoltage(_ value: String) -> String { title("high-battery-voltage", value) }

    private func title(_ prefix: String, _ value: String) -> String {
        "\(prefix):\(value)"
    }
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
