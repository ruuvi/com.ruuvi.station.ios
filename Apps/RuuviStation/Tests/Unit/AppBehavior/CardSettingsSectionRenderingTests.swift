import RuuviLocalization
import RuuviOntology
import SwiftUI
import UIKit
import Vision
import XCTest
@testable import station

@MainActor final class CardSettingsSectionRenderingTests: XCTestCase {
    func testMoreInfoRendersIdentityMeasurementsAndBatteryWarning() async throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let snapshot = RuuviTagCardSnapshot.create(
            id: "details-preview", name: "Greenhouse", luid: nil, mac: "AA:BB:CC:DD:EE:FF".mac,
            serviceUUID: nil, isCloud: false, isOwner: true, isConnectable: true, version: 5)
        var record = fixture.record()
        record.voltage = .init(value: 2.4, unit: .volts)
        snapshot.latestRawRecord = record
        snapshot.displayData.voltage = 2.4
        snapshot.displayData.batteryNeedsReplacement = true
        snapshot.displayData.source = .advertisement
        snapshot.displayData.txPower = 4
        snapshot.displayData.measurementSequenceNumber = 42
        snapshot.capabilities.showBatteryStatus = true
        let state = CardsSettingsState(snapshot: snapshot, measurementService: fixture.measurement)
        let root = CardsSettingsMoreInfoSectionView().environmentObject(state).environmentObject(CardsSettingsActions())
        let text = try await renderedText(root, name: "Sensor details")
        XCTAssertTrue(text.contains("AA:BB:CC:DD:EE:FF"), text)
        XCTAssertTrue(text.localizedCaseInsensitiveContains(RuuviLocalization.batteryVoltage), text)
        XCTAssertTrue(text.replacingOccurrences(of: ",", with: ".").contains("2.4"), text)
        XCTAssertTrue(text.contains("42"), text)
        XCTAssertTrue(text.localizedCaseInsensitiveContains(RuuviLocalization.TagSettings.DataFormatTitleLabel.text), text)
    }

    func testLegacySensorDetailsExplainUnavailableValues() async throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        fixture.snapshot.displayData.version = 3
        let state = CardsSettingsState(snapshot: fixture.snapshot, measurementService: fixture.measurement)
        let root = CardsSettingsMoreInfoSectionView().environmentObject(state).environmentObject(CardsSettingsActions())
        let text = try await renderedText(root, name: "Sensor details without measurements")
        XCTAssertTrue(text.localizedCaseInsensitiveContains(RuuviLocalization.TagSettings.Label.NoValues.text), text)
    }

    func testOffsetRowsDisplayCurrentCalibrationAndHideUnavailableMeasurements() async throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        fixture.snapshot.latestRawRecord = fixture.record()
        fixture.snapshot.calibration.temperatureOffset = "1.5 °C"
        fixture.snapshot.calibration.humidityOffset = "2.0 %"
        fixture.snapshot.calibration.pressureOffset = "3.5 hPa"
        fixture.snapshot.calibration.isHumidityOffsetVisible = true
        fixture.snapshot.calibration.isPressureOffsetVisible = true
        let state = CardsSettingsState(snapshot: fixture.snapshot, measurementService: fixture.measurement)
        let root = CardsSettingsOffsetCorrectionSectionView()
            .environmentObject(state).environmentObject(CardsSettingsActions())
        let text = try await renderedText(root, name: "Sensor calibration")
        for value in ["1.5", "2.0", "3.5"] { XCTAssertTrue(text.contains(value), text) }
        fixture.snapshot.calibration.isHumidityOffsetVisible = false
        fixture.snapshot.calibration.isPressureOffsetVisible = false
        fixture.snapshot.latestRawRecord = nil
        state.update(with: fixture.snapshot)
        let reduced = try await renderedText(root, name: "Calibration with unavailable measurements")
        XCTAssertTrue(reduced.contains("1.5"), reduced)
        XCTAssertFalse(reduced.contains("2.0"), reduced)
        XCTAssertFalse(reduced.contains("3.5"), reduced)
    }

    func testBasicInfoShowsOnlyAvailableOwnershipSharingAndDeviceControls() async throws {
        for full in [true, false] {
            let root = CardsSettingsBasicInfoSectionView(
                name: "Greenhouse", owner: "owner@example.com", shareStatus: "Three guests", ownersPlan: "Pro Plus",
                onEditName: {}, onOwnerTap: {}, onShareTap: {}, onVisibleMeasurementsTap: {},
                onLedBrightnessTap: {}, onNotesTap: {}, showsOwner: full, showOwnersPlan: full,
                showsShare: full, visibleMeasurementsValue: "Six measurements", ledBrightnessValue: "25%",
                showsVisibleMeasurementsRow: full, showsLedBrightnessRow: full,
                notes: full ? "First line\nSecond line\nThird line\nFourth line\nFifth line\nLast line" : "Short note",
                isNotesEditable: full)
            let text = try await renderedText(root, name: full ? "Cloud sensor settings" : "Local sensor settings")
            XCTAssertTrue(text.contains("Greenhouse"), text)
            for value in ["owner@example.com", "Pro Plus", "Three guests", "Six measurements", "25%"] {
                XCTAssertEqual(text.contains(value), full, value + "\n" + text)
            }
            if full {
                XCTAssertTrue(text.contains("First line"), text)
                XCTAssertTrue(text.localizedCaseInsensitiveContains(RuuviLocalization.showMore), text)
                XCTAssertFalse(text.contains("Last line"), text)
            } else {
                XCTAssertTrue(text.contains("Short note"), text)
            }
        }
    }

    private func renderedText<Content: View>(_ content: Content, name: String) async throws -> String {
        let host = UIHostingController(rootView: VStack { content; Spacer(minLength: 0) })
        host.overrideUserInterfaceStyle = .light
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 500, height: 1100)
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        host.loadViewIfNeeded()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(70))
        host.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { host.view.layer.render(in: $0.cgContext) }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let text = (request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []).joined(separator: "\n")
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return text
    }
}
