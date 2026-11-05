import Foundation
import RuuviCloud
import RuuviOntology
import SwiftUI
import UIKit
import WidgetKit
import XCTest
@testable import RuuviWidgets

@MainActor final class WidgetRenderingTests: XCTestCase {
    func testSingleSensorWidgetsRenderAllSupportedFamiliesAndDataStates() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let record = fixture.record(version: 6)
        let entries = [
            WidgetEntry.placeholder(), WidgetEntry.empty(),
            WidgetEntry(
                date: fixture.date, isAuthorized: true, isPreview: false, tag: .preview,
                record: record, settings: nil, cloudSettings: nil, config: fixture.config(.aqiIndex)),
            WidgetEntry(
                date: fixture.date, isAuthorized: false, isPreview: false, tag: .preview,
                record: record, settings: nil, cloudSettings: nil, config: fixture.config(.co2ppm)),
        ]
        for family: WidgetFamily in [.systemSmall, .accessoryInline, .accessoryRectangular, .accessoryCircular] {
            for (index, entry) in entries.enumerated() {
                let view = SingleSensorWidgetEntryView(entry: entry, familyOverride: family)
                try render(
                    view, size: CGSize(width: 180, height: family == .accessoryInline ? 50 : 180),
                    name: "Single-\(family)-\(index)")
            }
        }
    }

    func testMultiSensorWidgetsRenderEachSizeAndEmptyState() throws {
        for family: WidgetFamily in [.systemMedium, .systemLarge, .systemExtraLarge] {
            let size = CGSize(
                width: family == .systemExtraLarge ? 700 : 350, height: family == .systemMedium ? 180 : 350)
            let entry = MultiSensorWidgetEntry.placeholder(for: family)
            XCTAssertFalse(entry.sensors.isEmpty)
            for scheme: ColorScheme in [.light, .dark] {
                let view = MultiSensorWidgetEntryView(entry: entry, familyOverride: family).environment(
                    \.colorScheme, scheme)
                try render(view, size: size, name: "Multi-\(family)-\(scheme)")
            }
        }
        try render(
            MultiSensorWidgetEntryView(entry: .empty()), size: CGSize(width: 350, height: 180), name: "Multi-empty")
    }

    func testChangedMeasurementProducesChangedWidgetImage() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        func entry(_ temperature: Double) -> WidgetEntry {
            WidgetEntry(
                date: fixture.date, isAuthorized: true, isPreview: true, tag: .preview,
                record: fixture.record(temperature: temperature), settings: nil, cloudSettings: nil,
                config: fixture.config(.temperatureC))
        }
        let first = try render(
            SimpleWidgetView(entry: entry(20)), size: CGSize(width: 180, height: 180), name: "Temperature-20")
        let second = try render(
            SimpleWidgetView(entry: entry(25)), size: CGSize(width: 180, height: 180), name: "Temperature-25")
        XCTAssertNotEqual(first.pngData(), second.pngData())
    }

    func testCircularMeasurementRemainsVisibleInLightAndDarkThemes() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        func entry(_ temperature: Double) -> WidgetEntry {
            WidgetEntry(
                date: fixture.date, isAuthorized: true, isPreview: true, tag: .preview,
                record: fixture.record(temperature: temperature), settings: nil, cloudSettings: nil,
                config: fixture.config(.temperatureC))
        }
        for scheme: ColorScheme in [.light, .dark] {
            let first = try render(
                SimpleWidgetViewCircular(entry: entry(20)).environment(\.colorScheme, scheme),
                size: CGSize(width: 120, height: 120), name: "Circular-20-\(scheme)")
            let second = try render(
                SimpleWidgetViewCircular(entry: entry(25)).environment(\.colorScheme, scheme),
                size: CGSize(width: 120, height: 120), name: "Circular-25-\(scheme)")
            XCTAssertNotEqual(first.pngData(), second.pngData(), "A changed value must be visible in \(scheme)")
        }
    }

    func testMultiWidgetRendersLiveSingleOddAndMissingMeasurements() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        var record = fixture.record()
        record.macId = nil
        record.luid = nil
        for codes: [RuuviCloudSensorVisibilityCode] in [
            [.temperatureC], [.temperatureC, .humidityRelative, .pressurePa],
        ] {
            let sensor = MultiSensorWidgetSensorItem(
                id: "test", sensorId: "", name: "Unlinked sensor", record: record,
                settings: nil, cloudSettings: nil, deviceType: .ruuviTag,
                selectedCodes: codes)
            let entry = MultiSensorWidgetEntry(
                date: fixture.date, isAuthorized: true, isPreview: false, sensors: [sensor])
            try render(
                MultiSensorWidgetEntryView(entry: entry, familyOverride: .systemMedium),
                size: CGSize(width: 350, height: 180), name: "Multi-live-\(codes.count)")
        }
        let missing = MultiSensorWidgetSensorItem(
            id: "missing", sensorId: "missing", name: "No readings", record: nil,
            settings: nil, cloudSettings: nil, deviceType: .ruuviTag, selectedCodes: [])
        let entry = MultiSensorWidgetEntry(date: fixture.date, isAuthorized: true, isPreview: false, sensors: [missing])
        try render(
            MultiSensorWidgetEntryView(entry: entry, familyOverride: .systemLarge),
            size: CGSize(width: 350, height: 350), name: "Multi-missing-readings")
    }

    @discardableResult private func render<V: View>(_ view: V, size: CGSize, name: String) throws -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage, name)
        XCTAssertEqual(image.size, size, name)
        XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 100, name)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }
}
