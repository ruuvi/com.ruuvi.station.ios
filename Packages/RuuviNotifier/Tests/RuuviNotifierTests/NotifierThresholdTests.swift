import Foundation
import RuuviNotification
import RuuviNotifier
import RuuviOntology
#if SWIFT_PACKAGE
    @testable import RuuviNotifierImpl
#else
    @testable import RuuviNotifier
#endif
import XCTest

@MainActor final class NotifierThresholdTests: XCTestCase {
    func testEveryThresholdProducesTheRightLowHighNotificationAndObserverStateForLocalAndCloudRecords() async {
        let fixture = NotifierFixture()
        defer { fixture.close() }
        for row in ThresholdRow.all {
            fixture.alerts.alerts = [row.alert.rawValue: row.alert]
            for network in [false, true] {
                for (value, expected): (Double, LowHighNotificationReason?) in [
                    (row.below, .low), (row.above, .high), (row.safe, nil),
                ] {
                    var record = fixture.record()
                    row.apply(&record, value)
                    await fixture.process(record, network: network)
                    let context = "\(row.alert.rawValue), \(value), cloud=\(network)"
                    XCTAssertEqual(fixture.observer.overall.count, 1, context)
                    XCTAssertEqual(fixture.observer.overall.first?.1, expected != nil, context)
                    let state = fixture.observer.types.first { $0.1.rawValue == row.alert.rawValue }
                    XCTAssertEqual(state?.2, expected != nil, context)
                    if let expected {
                        XCTAssertEqual(fixture.notifications.alerts.count, 1, context)
                        let notification = fixture.notifications.alerts.first
                        XCTAssertEqual(notification?.type.rawValue, row.alert.rawValue, context)
                        XCTAssertEqual(notification?.uuid, network ? fixture.mac.value : fixture.luid.value, context)
                        let prefix = expected == .low ? "low" : "high"
                        XCTAssertTrue(notification?.title.hasPrefix(prefix + row.title + "|") == true, context)
                        XCTAssertFalse(notification?.title.hasSuffix("|") ?? true, context)
                        XCTAssertEqual(notification?.reason, expected, context)
                    } else {
                        XCTAssertTrue(fixture.notifications.alerts.isEmpty, context)
                    }
                }
            }
        }
    }

    func testExactBoundariesDoNotTriggerAndSilentProcessingStillUpdatesAlertBells() async {
        let fixture = NotifierFixture()
        defer { fixture.close() }
        for row in ThresholdRow.all {
            fixture.alerts.alerts = [row.alert.rawValue: row.alert]
            for network in [false, true] {
                for value in row.boundaries {
                    var record = fixture.record()
                    row.apply(&record, value)
                    await fixture.process(record, network: network)
                    XCTAssertTrue(fixture.notifications.alerts.isEmpty, row.alert.rawValue)
                    XCTAssertEqual(fixture.observer.overall.first?.1, false, row.alert.rawValue)
                }
                var record = fixture.record()
                row.apply(&record, row.above)
                await fixture.process(record, network: network, trigger: false)
                XCTAssertTrue(fixture.notifications.alerts.isEmpty, row.alert.rawValue)
                XCTAssertEqual(fixture.observer.overall.first?.1, true, row.alert.rawValue)
            }
        }
    }

    func testMissingReadingsUnregisteredSensorsAndMissingLocalIdentityNeverProduceAnAlert() async {
        let fixture = NotifierFixture()
        defer { fixture.close() }
        for row in ThresholdRow.all {
            fixture.alerts.alerts = [row.alert.rawValue: row.alert]
            for network in [false, true] {
                await fixture.process(fixture.record(), network: network)
                XCTAssertTrue(fixture.notifications.alerts.isEmpty, row.alert.rawValue)
                XCTAssertEqual(fixture.observer.overall.first?.1, false, row.alert.rawValue)
            }
        }
        fixture.alerts.registered = false
        await fixture.process(fixture.record(), network: false)
        XCTAssertTrue(fixture.observer.overall.isEmpty)
        await fixture.process(fixture.record(), network: true)
        XCTAssertTrue(fixture.observer.overall.isEmpty)
        fixture.alerts.registered = true
        var record = fixture.record()
        record.luid = nil
        await fixture.process(record, network: false)
        XCTAssertTrue(fixture.observer.overall.isEmpty)
    }

    func testSubscriptionsAreUniqueWeakAndIsolatedByIdentifier() async {
        let fixture = NotifierFixture()
        defer { fixture.close() }
        var extra: NotifierObserver? = NotifierObserver()
        weak var released = extra
        XCTAssertFalse(fixture.notifier.isSubscribed(extra!, to: fixture.luid.value))
        fixture.notifier.subscribe(extra!, to: fixture.luid.value)
        fixture.notifier.subscribe(extra!, to: fixture.luid.value)
        XCTAssertTrue(fixture.notifier.isSubscribed(extra!, to: fixture.luid.value))
        XCTAssertFalse(fixture.notifier.isSubscribed(extra!, to: "unrelated"))
        await fixture.process(fixture.record(), network: false)
        XCTAssertEqual(extra?.overall.count, 1)
        await fixture.process(fixture.record(), network: true)
        XCTAssertEqual(extra?.overall.count, 1)
        extra = nil
        XCTAssertNil(released)
        await fixture.process(fixture.record(), network: false)
        XCTAssertEqual(fixture.observer.overall.count, 1)
    }
}

private struct ThresholdRow {
    let alert: AlertType
    let title: String
    let below: Double
    let above: Double
    let safe: Double
    var boundaries: [Double] = []
    let apply: (inout RuuviTagSensorRecordStruct, Double) -> Void

    static var all: [ThresholdRow] {
        [
            .init(
                alert: .temperature(lower: 10, upper: 30), title: "Temperature", below: 9, above: 31, safe: 20,
                boundaries: [10, 30], apply: { $0.temperature = Temperature($1) }),
            .init(
                alert: .relativeHumidity(lower: 0.2, upper: 0.8), title: "Humidity", below: 0.1, above: 0.9, safe: 0.5,
                boundaries: [0.2, 0.8],
                apply: {
                    $0.temperature = Temperature(20)
                    $0.humidity = Humidity(value: $1, unit: .relative(temperature: Temperature(20)!))
                }),
            .init(
                alert: .humidity(lower: .init(value: 5, unit: .absolute), upper: .init(value: 10, unit: .absolute)),
                title: "AbsoluteHumidity", below: 4, above: 11, safe: 7,
                apply: {
                    $0.temperature = Temperature(20)
                    $0.humidity = Humidity(value: $1, unit: .absolute)
                }),
            .init(
                alert: .dewPoint(lower: 5, upper: 15), title: "DewPoint", below: 0.1, above: 0.9, safe: 0.5,
                apply: {
                    $0.temperature = Temperature(20)
                    $0.humidity = Humidity(value: $1, unit: .relative(temperature: Temperature(20)!))
                }),
            .init(
                alert: .pressure(lower: 900, upper: 1100), title: "Pressure", below: 800, above: 1200, safe: 1000,
                boundaries: [900, 1100], apply: { $0.pressure = Pressure($1) }),
            .init(
                alert: .signal(lower: -90, upper: -50), title: "Signal", below: -100, above: -40, safe: -70,
                boundaries: [-90, -50], apply: { $0.rssi = Int($1) }),
            .init(
                alert: .batteryVoltage(lower: 2, upper: 3), title: "BatteryVoltage", below: 1.5, above: 3.5, safe: 2.5,
                boundaries: [2, 3], apply: { $0.voltage = Voltage(value: $1, unit: .volts) }),
            .init(
                alert: .aqi(lower: 20, upper: 80), title: "AQI", below: 60, above: 0, safe: 30,
                apply: {
                    $0.co2 = 420
                    $0.pm25 = $1
                }),
        ] + scalarRows
    }

    private static var scalarRows: [ThresholdRow] {
        let rows: [(AlertType, String, WritableKeyPath<RuuviTagSensorRecordStruct, Double?>)] = [
            (.carbonDioxide(lower: 10, upper: 30), "CarbonDioxide", \.co2),
            (.pMatter1(lower: 10, upper: 30), "PMatter1", \.pm1),
            (.pMatter25(lower: 10, upper: 30), "PMatter25", \.pm25),
            (.pMatter4(lower: 10, upper: 30), "PMatter4", \.pm4),
            (.pMatter10(lower: 10, upper: 30), "PMatter10", \.pm10),
            (.voc(lower: 10, upper: 30), "VOC", \.voc),
            (.nox(lower: 10, upper: 30), "NOx", \.nox),
            (.soundInstant(lower: 10, upper: 30), "SoundInstant", \.dbaInstant),
            (.soundAverage(lower: 10, upper: 30), "SoundAverage", \.dbaAvg),
            (.soundPeak(lower: 10, upper: 30), "SoundPeak", \.dbaPeak),
            (.luminosity(lower: 10, upper: 30), "Luminosity", \.luminance),
        ]
        return rows.map { alert, title, path in
            .init(
                alert: alert, title: title, below: 9, above: 31, safe: 20, boundaries: [10, 30],
                apply: { $0[keyPath: path] = $1 })
        }
    }
}
