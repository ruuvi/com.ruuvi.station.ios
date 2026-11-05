import Foundation
import Humidity
import RuuviLocalization
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class AlertSettingsBuilderTests: XCTestCase {
    func testAllAlertKindsPreserveVisibleOrderHeaderStateDescriptionsAndValidSliders() throws {
        let fixture = AlertBuilderFixture()
        defer { fixture.close() }
        let all = AlertType.allCases
        for (index, alert) in all.enumerated() {
            fixture.configure(alert, active: index % 3 != 0, firing: index % 3 == 2)
        }
        let sections = fixture.sections()
        XCTAssertEqual(Set(sections.map { $0.alertType.rawValue }), Set(all.map(\.rawValue)))
        XCTAssertEqual(sections.count, all.count, "Repeated variants must not duplicate alert controls")
        let measurementOrder = fixture.variants.compactMap { $0.toAlertType()?.rawValue }
        XCTAssertEqual(Array(sections.prefix(measurementOrder.count)).map { $0.alertType.rawValue }, measurementOrder)
        for (index, alert) in all.enumerated() {
            let section = try XCTUnwrap(sections.first { $0.alertType.rawValue == alert.rawValue })
            XCTAssertFalse(section.title.isEmpty)
            XCTAssertFalse(section.legacyTitle.isEmpty)
            XCTAssertEqual(section.id, "alert." + alert.rawValue)
            XCTAssertEqual(section.headerState.isOn, index % 3 != 0)
            XCTAssertEqual(section.configuration.isEnabled, index % 3 != 0)
            XCTAssertEqual(
                section.headerState.alertState, index % 3 == 2 ? .firing : (index % 3 == 1 ? .registered : .empty))
            XCTAssertEqual(section.headerState.mutedTill, fixture.muted)
            XCTAssertEqual(section.configuration.customDescriptionText, "Custom " + alert.rawValue)
            XCTAssertTrue(section.isInteractionEnabled)
            if let slider = section.configuration.sliderConfiguration {
                XCTAssertTrue(slider.range.contains(slider.selectedRange.lowerBound), alert.rawValue)
                XCTAssertTrue(slider.range.contains(slider.selectedRange.upperBound), alert.rawValue)
                XCTAssertNotNil(section.configuration.latestMeasurement, alert.rawValue)
                XCTAssertFalse(slider.selectedBoundsSummary.isEmpty)
            }
        }
        fixture.measurements.snapshot.capabilities.hideSwitchStatusLabel = true
        XCTAssertTrue(fixture.sections().allSatisfy { !$0.headerState.showStatusLabel })
    }

    func testTemperatureDewPointAndPressureLimitsUseTheSelectedDisplayUnits() throws {
        let fixture = AlertBuilderFixture()
        defer { fixture.close() }
        for (unit, low, high) in [
            (TemperatureUnit.celsius, 0.0, 20.0), (.fahrenheit, 32.0, 68.0), (.kelvin, 273.15, 293.15),
        ] {
            fixture.measurements.settings.temperatureUnit = unit
            for alert in [AlertType.temperature(lower: 0, upper: 20), .dewPoint(lower: 0, upper: 20)] {
                fixture.configure(alert, lower: 0, upper: 20)
                let slider = try XCTUnwrap(fixture.section(alert)?.configuration.sliderConfiguration)
                XCTAssertEqual(slider.selectedRange.lowerBound, low, accuracy: 0.001)
                XCTAssertEqual(slider.selectedRange.upperBound, high, accuracy: 0.001)
                XCTAssertEqual(slider.unit, unit.symbol)
            }
        }
        let pressure = AlertType.pressure(lower: 900, upper: 1100)
        for (unit, low, high) in [(UnitPressure.hectopascals, 900.0, 1100.0), (.inchesOfMercury, 26.577, 32.484)] {
            fixture.measurements.settings.pressureUnit = unit
            fixture.configure(pressure, lower: 900, upper: 1100)
            let slider = try XCTUnwrap(fixture.section(pressure)?.configuration.sliderConfiguration)
            XCTAssertEqual(slider.selectedRange.lowerBound, low, accuracy: 0.005)
            XCTAssertEqual(slider.selectedRange.upperBound, high, accuracy: 0.005)
            XCTAssertEqual(slider.unit, unit.symbol)
        }
    }

    func testCustomRangesPreserveOutOfStandardLimitsAndExplicitCustomSelection() throws {
        let fixture = AlertBuilderFixture()
        defer { fixture.close() }
        let cases: [AlertRangeCase] = [
            .init(alert: .temperature(lower: -50, upper: 140), selected: -50...140, manual: -55...150),
            .init(alert: .carbonDioxide(lower: 300, upper: 10000), selected: 300...10000, manual: 0...40000),
            .init(alert: .pMatter25(lower: 1, upper: 500), selected: 1...500, manual: 0...1000),
        ]
        for entry in cases {
            let alert = entry.alert
            let lower = entry.selected.lowerBound
            let upper = entry.selected.upperBound
            let manual = entry.manual
            fixture.configure(alert, lower: lower, upper: upper)
            let slider = try XCTUnwrap(fixture.section(alert)?.configuration.sliderConfiguration)
            XCTAssertEqual(slider.range, manual)
            XCTAssertEqual(slider.selectedRange.lowerBound, lower, accuracy: 0.001)
            XCTAssertEqual(slider.selectedRange.upperBound, upper, accuracy: 0.001)
            fixture.configure(alert, lower: nil, upper: nil)
        }
        let custom = fixture.sections(custom: .init(temperature: true, carbonDioxide: true, particulateMatter: true))
        for entry in cases {
            let alert = entry.alert
            let manual = entry.manual
            XCTAssertEqual(
                custom.first { $0.alertType.rawValue == alert.rawValue }?.configuration.sliderConfiguration?.range,
                manual)
        }
    }

    func testReversedNonFiniteAndOutOfBoundsLimitsAreNormalizedForEverySlider() {
        let fixture = AlertBuilderFixture()
        defer { fixture.close() }
        for (lower, upper) in [(Double.nan, Double.infinity), (Double.infinity, -Double.infinity), (10000.0, -10000.0)]
        {
            for alert in AlertType.allCases { fixture.configure(alert, lower: lower, upper: upper) }
            for section in fixture.sections() {
                guard let slider = section.configuration.sliderConfiguration else { continue }
                XCTAssertTrue(slider.selectedRange.lowerBound.isFinite, section.id)
                XCTAssertTrue(slider.selectedRange.upperBound.isFinite, section.id)
                XCTAssertTrue(slider.manualRange.contains(slider.selectedRange.lowerBound), section.id)
                XCTAssertTrue(slider.manualRange.contains(slider.selectedRange.upperBound), section.id)
                XCTAssertLessThanOrEqual(slider.selectedRange.lowerBound, slider.selectedRange.upperBound)
            }
        }
    }

    func testMissingReadingsAndConnectionCapabilitiesControlWhichAlertsAreShown() {
        let fixture = AlertBuilderFixture()
        defer { fixture.close() }
        fixture.measurements.snapshot.latestRawRecord = nil
        XCTAssertEqual(Set(fixture.sections().map { $0.alertType.rawValue }), ["connection", "cloudConnection"])
        fixture.measurements.snapshot.connectionData.isConnectable = false
        XCTAssertEqual(fixture.sections().map { $0.alertType.rawValue }, ["cloudConnection"])
        fixture.measurements.snapshot.capabilities.isCloudConnectionAlertsAvailable = false
        XCTAssertTrue(fixture.sections().isEmpty)
        fixture.measurements.snapshot.latestRawRecord = fixture.measurements.record()
        fixture.measurements.snapshot.connectionData.isConnectable = true
        fixture.measurements.snapshot.capabilities.showKeepConnection = false
        XCTAssertFalse(fixture.sections().contains { $0.alertType.rawValue == "connection" })
        let withoutFormatter = CardsSettingsAlertsBuilder.makeSections(
            snapshot: fixture.measurements.snapshot, measurementService: nil)
        XCTAssertFalse(withoutFormatter.isEmpty)
        XCTAssertTrue(withoutFormatter.allSatisfy { !$0.title.isEmpty })
    }

    func testSoundAlertsUseSoundPressureUnitsAndSignalKeepsRadioPowerUnits() throws {
        let fixture = AlertBuilderFixture()
        defer { fixture.close() }
        for alert in [
            AlertType.soundInstant(lower: 0, upper: 100), .soundPeak(lower: 0, upper: 100),
            .soundAverage(lower: 0, upper: 100),
        ] {
            let configuration = try XCTUnwrap(fixture.section(alert)?.configuration)
            XCTAssertEqual(configuration.sliderConfiguration?.unit, RuuviLocalization.unitSound)
            XCTAssertEqual(configuration.latestMeasurementDisplay?.suffix, RuuviLocalization.unitSound)
        }
        let signal = try XCTUnwrap(fixture.section(.signal(lower: -90, upper: -30))?.configuration)
        XCTAssertEqual(signal.sliderConfiguration?.unit, RuuviLocalization.dBm)
        XCTAssertEqual(signal.latestMeasurementDisplay?.suffix, RuuviLocalization.dBm)
    }

    func testInvalidCloudDelaysFallBackBeforeIntegerFormattingAndValidDelaysSurvive() throws {
        let fixture = AlertBuilderFixture()
        defer { fixture.close() }
        for delay in [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude, -1, 0, 119, 120, 3600] {
            let normalized = RuuviAlertConstants.CloudConnection.normalizedUnseenDuration(delay)
            let expected = delay == 120 || delay == 3600 ? delay : 900
            XCTAssertEqual(normalized, expected)
            guard normalized.isFinite, normalized < Double(Int.max) else { continue }
            let alert = AlertType.cloudConnection(unseenDuration: delay)
            fixture.configure(alert, delay: delay)
            let section = try XCTUnwrap(fixture.section(alert))
            XCTAssertEqual(
                section.configuration.headerSummaryText,
                RuuviLocalization.alertCloudConnectionDelaySummary(Int(expected / 60)))
        }
    }
}

@MainActor final class AlertBuilderFixture {
    let measurements = MeasurementFixture()
    let muted = Date(timeIntervalSince1970: 1_900_000_000)
    let variants: [MeasurementDisplayVariant]
    init() {
        variants = AlertType.allCases.compactMap { alert in
            switch alert {
            case .humidity: return .init(type: .humidity, humidityUnit: .gm3)
            case .relativeHumidity: return .init(type: .humidity, humidityUnit: .percent)
            case .dewPoint: return .init(type: .humidity, temperatureUnit: .celsius, humidityUnit: .dew)
            default: return alert.toMeasurementType().map { MeasurementDisplayVariant(type: $0) }
            }
        }.reversed()
        measurements.snapshot.latestRawRecord = measurements.record()
        measurements.snapshot.displayData.measurementVisibility = .init(
            usesDefaultOrder: false, availableVariants: variants,
            visibleVariants: variants + variants + [.init(type: .accelerationX)])
        measurements.snapshot.capabilities.showKeepConnection = true
        measurements.snapshot.capabilities.isCloudConnectionAlertsAvailable = true
        measurements.snapshot.connectionData.isConnectable = true
    }
    func close() { measurements.cleanup() }
    func configure(
        _ type: AlertType, active: Bool = true, firing: Bool = false,
        lower: Double? = nil, upper: Double? = nil, delay: Double? = nil
    ) {
        measurements.snapshot.updateAlertConfig(
            for: type,
            config: .init(
                type: type.toMeasurementType(), alertType: type, isActive: active, isFiring: firing,
                mutedTill: muted, lowerBound: lower, upperBound: upper, description: "Custom " + type.rawValue,
                unseenDuration: delay))
    }
    func sections(custom: CardsSettingsAlertsBuilder.CustomRangeSelection = .standard)
        -> [CardsSettingsAlertSectionModel]
    {
        var measurement = measurements.measurement
        measurement.units = .init(
            temperatureUnit: measurements.settings.temperatureUnit.unitTemperature,
            humidityUnit: measurements.settings.humidityUnit, pressureUnit: measurements.settings.pressureUnit)
        return CardsSettingsAlertsBuilder.makeSections(
            snapshot: measurements.snapshot, measurementService: measurement, customRanges: custom)
    }
    func section(_ type: AlertType) -> CardsSettingsAlertSectionModel? {
        sections().first { $0.alertType.rawValue == type.rawValue }
    }
}

private struct AlertRangeCase {
    let alert: AlertType
    let selected: ClosedRange<Double>
    let manual: ClosedRange<Double>
}
