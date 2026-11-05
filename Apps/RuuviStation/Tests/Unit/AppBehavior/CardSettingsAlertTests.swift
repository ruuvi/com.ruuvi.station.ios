import Foundation
import Humidity
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class CardSettingsAlertTests: XCTestCase {
    func testEveryMeasurementAlertPersistsEnabledStateBoundsAndDescriptionInCanonicalUnits() async {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        var measurement = fixture.measurements.measurement
        measurement.units = .init(temperatureUnit: .celsius, humidityUnit: .percent, pressureUnit: .hectopascals)
        let service = fixture.measurements.alerts
        let sensor = fixture.sensor
        for metric in CardAlertMetric.all {
            fixture.measurements.registeredAlerts.append(metric.type)
            fixture.snapshot.updateAlertConfig(
                for: metric.type,
                config: .init(
                    type: metric.type.toMeasurementType(), alertType: metric.type, isActive: false, isFiring: false, mutedTill: nil,
                    lowerBound: metric.lower - 1, upperBound: metric.upper - 1))
            fixture.presenter.viewDidChangeAlertState(for: metric.type, isOn: true)
            XCTAssertTrue(service.isOn(type: metric.type, for: sensor), metric.type.rawValue)
            fixture.presenter.viewDidChangeAlertLowerBound(for: metric.type, lower: CGFloat(metric.lower))
            fixture.presenter.viewDidChangeAlertUpperBound(for: metric.type, upper: CGFloat(metric.upper))
            let description = "Alarm " + metric.type.rawValue
            fixture.presenter.viewDidChangeAlertDescription(for: metric.type, description: description)
            await waitForAppState("persisted alert " + metric.type.rawValue) {
                guard let lower = metric.readLower(service, sensor), let upper = metric.readUpper(service, sensor)
                else { return false }
                return abs(lower - metric.lower * metric.scale) < 0.001
                    && abs(upper - metric.upper * metric.scale) < 0.001
            }
            XCTAssertEqual(metric.readDescription(service, sensor), description)
            let muted = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 3600)
            service.mute(type: metric.type, for: sensor, till: muted)
            fixture.presenter.viewDidChangeAlertState(for: metric.type, isOn: true)
            XCTAssertEqual(
                service.mutedTill(type: metric.type, for: sensor), muted, "An unchanged toggle must not clear mute")
            fixture.presenter.viewDidChangeAlertState(for: metric.type, isOn: false)
            XCTAssertFalse(service.isOn(type: metric.type, for: sensor))
            XCTAssertNil(service.mutedTill(type: metric.type, for: sensor))
            fixture.presenter.viewDidChangeAlertDescription(for: metric.type, description: nil)
            XCTAssertNil(metric.readDescription(service, sensor))
        }
    }

    func testDisplayedFahrenheitAndPressureBoundsConvertBackToStorageUnits() async {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        var measurement = fixture.measurements.measurement
        measurement.units = .init(temperatureUnit: .fahrenheit, humidityUnit: .dew, pressureUnit: .inchesOfMercury)
        let temperature = AlertType.temperature(lower: 0, upper: 100)
        let dew = AlertType.dewPoint(lower: 0, upper: 100)
        let pressure = AlertType.pressure(lower: 900, upper: 1100)
        fixture.measurements.registeredAlerts += [temperature, dew, pressure]
        fixture.presenter.viewDidChangeAlertLowerBound(for: temperature, lower: 32)
        fixture.presenter.viewDidChangeAlertUpperBound(for: temperature, upper: 77)
        fixture.presenter.viewDidChangeAlertLowerBound(for: dew, lower: 50)
        fixture.presenter.viewDidChangeAlertUpperBound(for: dew, upper: 68)
        let displayedPressure = Measurement(value: 1000, unit: UnitPressure.hectopascals).converted(
            to: .inchesOfMercury
        ).value
        fixture.presenter.viewDidChangeAlertLowerBound(for: pressure, lower: CGFloat(displayedPressure))
        await waitForAppState("converted temperature bounds") {
            abs((fixture.measurements.alerts.upperCelsius(for: fixture.sensor) ?? -100) - 25) < 0.001
                && abs((fixture.measurements.alerts.upperDewPoint(for: fixture.sensor) ?? -100) - 20) < 0.001
        }
        XCTAssertEqual(fixture.measurements.alerts.lowerCelsius(for: fixture.sensor) ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(fixture.measurements.alerts.lowerDewPoint(for: fixture.sensor) ?? -1, 10, accuracy: 0.001)
        await waitForAppState("converted pressure") {
            fixture.measurements.alerts.lowerPressure(for: fixture.sensor) != nil
        }
        XCTAssertEqual(fixture.measurements.alerts.lowerPressure(for: fixture.sensor) ?? -1, 1000, accuracy: 0.001)
    }

    func testCloudDelayRejectsInvalidValuesAndMovementToggleUsesCurrentCounter() async {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        let movement = AlertType.movement(last: 0)
        let cloud = AlertType.cloudConnection(unseenDuration: 900)
        fixture.measurements.registeredAlerts += [movement, cloud, .connection]
        fixture.snapshot.latestRawRecord = fixture.measurements.record()
        fixture.presenter.viewDidChangeAlertState(for: movement, isOn: true)
        XCTAssertEqual(fixture.measurements.alerts.movementCounter(for: fixture.sensor), 12)
        fixture.presenter.viewDidChangeAlertDescription(for: movement, description: "Moved")
        XCTAssertEqual(fixture.measurements.alerts.movementDescription(for: fixture.sensor), "Moved")
        fixture.presenter.viewDidChangeAlertState(for: movement, isOn: false)
        XCTAssertFalse(fixture.measurements.alerts.isOn(type: movement, for: fixture.sensor))
        fixture.presenter.viewDidChangeCloudConnectionAlertUnseenDuration(duration: 1200)
        await waitForAppState("cloud delay persisted") {
            fixture.measurements.alerts.cloudConnectionUnseenDuration(for: fixture.sensor) == 1200
        }
        fixture.presenter.viewDidChangeCloudConnectionAlertUnseenDuration(duration: -1)
        fixture.presenter.viewDidChangeCloudConnectionAlertUnseenDuration(duration: 1200)
        XCTAssertEqual(fixture.snapshot.getAlertConfig(for: cloud)?.unseenDuration, 1200)
        fixture.presenter.viewDidChangeAlertDescription(for: cloud, description: "Offline")
        fixture.presenter.viewDidChangeAlertDescription(for: .connection, description: "Disconnected")
        XCTAssertEqual(fixture.measurements.alerts.cloudConnectionDescription(for: fixture.sensor), "Offline")
        XCTAssertEqual(fixture.measurements.alerts.connectionDescription(for: fixture.sensor), "Disconnected")
    }
}

struct CardAlertMetric {
    let type: AlertType
    let lower: Double
    let upper: Double
    let scale: Double
    let readLower: (RuuviServiceAlert, PhysicalSensor) -> Double?
    let readUpper: (RuuviServiceAlert, PhysicalSensor) -> Double?
    let readDescription: (RuuviServiceAlert, PhysicalSensor) -> String?
}

extension CardAlertMetric {
    static let all: [CardAlertMetric] = [
        .init(
            type: .temperature(lower: -9, upper: 32), lower: -9, upper: 32, scale: 1,
            readLower: { $0.lowerCelsius(for: $1) }, readUpper: { $0.upperCelsius(for: $1) },
            readDescription: { $0.temperatureDescription(for: $1) }),
        .init(
            type: .relativeHumidity(lower: 21, upper: 82), lower: 21, upper: 82, scale: 0.01,
            readLower: { $0.lowerRelativeHumidity(for: $1) }, readUpper: { $0.upperRelativeHumidity(for: $1) },
            readDescription: { $0.relativeHumidityDescription(for: $1) }),
        .init(
            type: .dewPoint(lower: 1, upper: 12), lower: 1, upper: 12, scale: 1,
            readLower: { $0.lowerDewPoint(for: $1) }, readUpper: { $0.upperDewPoint(for: $1) },
            readDescription: { $0.dewPointDescription(for: $1) }),
        .init(
            type: .pressure(lower: 951, upper: 1052), lower: 951, upper: 1052, scale: 1,
            readLower: { $0.lowerPressure(for: $1) }, readUpper: { $0.upperPressure(for: $1) },
            readDescription: { $0.pressureDescription(for: $1) }),
        .init(
            type: .signal(lower: -89, upper: -38), lower: -89, upper: -38, scale: 1,
            readLower: { $0.lowerSignal(for: $1) }, readUpper: { $0.upperSignal(for: $1) },
            readDescription: { $0.signalDescription(for: $1) }),
        .init(
            type: .aqi(lower: 11, upper: 92), lower: 11, upper: 92, scale: 1,
            readLower: { $0.lowerAQI(for: $1) }, readUpper: { $0.upperAQI(for: $1) },
            readDescription: { $0.aqiDescription(for: $1) }),
        .init(
            type: .carbonDioxide(lower: 501, upper: 1802), lower: 501, upper: 1802, scale: 1,
            readLower: { $0.lowerCarbonDioxide(for: $1) }, readUpper: { $0.upperCarbonDioxide(for: $1) },
            readDescription: { $0.carbonDioxideDescription(for: $1) }),
        .init(
            type: .pMatter1(lower: 11, upper: 22), lower: 11, upper: 22, scale: 1,
            readLower: { $0.lowerPM1(for: $1) }, readUpper: { $0.upperPM1(for: $1) },
            readDescription: { $0.pm1Description(for: $1) }),
        .init(
            type: .pMatter25(lower: 11, upper: 22), lower: 11, upper: 22, scale: 1,
            readLower: { $0.lowerPM25(for: $1) }, readUpper: { $0.upperPM25(for: $1) },
            readDescription: { $0.pm25Description(for: $1) }),
        .init(
            type: .pMatter4(lower: 11, upper: 22), lower: 11, upper: 22, scale: 1,
            readLower: { $0.lowerPM4(for: $1) }, readUpper: { $0.upperPM4(for: $1) },
            readDescription: { $0.pm4Description(for: $1) }),
        .init(
            type: .pMatter10(lower: 11, upper: 22), lower: 11, upper: 22, scale: 1,
            readLower: { $0.lowerPM10(for: $1) }, readUpper: { $0.upperPM10(for: $1) },
            readDescription: { $0.pm10Description(for: $1) }),
        .init(
            type: .voc(lower: 51, upper: 152), lower: 51, upper: 152, scale: 1,
            readLower: { $0.lowerVOC(for: $1) }, readUpper: { $0.upperVOC(for: $1) },
            readDescription: { $0.vocDescription(for: $1) }),
        .init(
            type: .nox(lower: 6, upper: 52), lower: 6, upper: 52, scale: 1,
            readLower: { $0.lowerNOX(for: $1) }, readUpper: { $0.upperNOX(for: $1) },
            readDescription: { $0.noxDescription(for: $1) }),
        .init(
            type: .soundInstant(lower: 21, upper: 92), lower: 21, upper: 92, scale: 1,
            readLower: { $0.lowerSoundInstant(for: $1) }, readUpper: { $0.upperSoundInstant(for: $1) },
            readDescription: { $0.soundInstantDescription(for: $1) }),
        .init(
            type: .soundAverage(lower: 21, upper: 92), lower: 21, upper: 92, scale: 1,
            readLower: { $0.lowerSoundAverage(for: $1) }, readUpper: { $0.upperSoundAverage(for: $1) },
            readDescription: { $0.soundAverageDescription(for: $1) }),
        .init(
            type: .soundPeak(lower: 21, upper: 92), lower: 21, upper: 92, scale: 1,
            readLower: { $0.lowerSoundPeak(for: $1) }, readUpper: { $0.upperSoundPeak(for: $1) },
            readDescription: { $0.soundPeakDescription(for: $1) }),
        .init(
            type: .luminosity(lower: 101, upper: 202), lower: 101, upper: 202, scale: 1,
            readLower: { $0.lowerLuminosity(for: $1) }, readUpper: { $0.upperLuminosity(for: $1) },
            readDescription: { $0.luminosityDescription(for: $1) }),
        .init(
            type: .batteryVoltage(lower: 2.4, upper: 3.3), lower: 2.4, upper: 3.3, scale: 1,
            readLower: { $0.lowerBatteryVoltage(for: $1) }, readUpper: { $0.upperBatteryVoltage(for: $1) },
            readDescription: { $0.batteryVoltageDescription(for: $1) }),
    ]
}
