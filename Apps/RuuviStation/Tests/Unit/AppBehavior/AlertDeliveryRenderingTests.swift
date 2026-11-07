import RuuviOntology
import SwiftUI
import UIKit
import Vision
import XCTest
@testable import station

@MainActor final class AlertDeliveryRenderingTests: XCTestCase {
    func testDeliveryPromptMessageAndActionRemainVisibleInBothThemes() async throws {
        let fixture = AlertBuilderFixture()
        defer { fixture.close() }
        let state = CardsSettingsState(
            snapshot: fixture.measurements.snapshot, measurementService: fixture.measurements.measurement)
        for style: UIUserInterfaceStyle in [.light, .dark] {
            state.updateAlertDeliveryPrompt(
                .init(
                    message: "Bluetooth alerts need permission", buttonTitle: "Open settings",
                    destination: .backgroundScanning))
            let view = UIHostingController(
                rootView: CardsAlertsView(state: state, displayMode: .alerts, onAlertDeliveryPromptTap: { _ in }))
            view.overrideUserInterfaceStyle = style
            let host = try AppViewHost(view)
            defer { host.close() }
            await waitForAppState("alert delivery view attached and rendered") {
                view.view.layoutIfNeeded()
                return view.view.window === host.window && view.view.bounds.height > 0
                    && view.view.allDescendants.contains { $0 is UIScrollView }
            }
            await flushAppBindings()
            view.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: view.view.bounds).image {
                view.view.layer.render(in: $0.cgContext)
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
            let text =
                request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ").lowercased()
                ?? ""
            XCTAssertTrue(text.contains("bluetooth alerts need permission"), text)
            XCTAssertTrue(text.contains("open settings"), text)
            let attachment = XCTAttachment(image: image)
            attachment.name = style == .light ? "Alert delivery prompt light" : "Alert delivery prompt dark"
            attachment.lifetime = .keepAlways
            add(attachment)
            state.updateAlertDeliveryPrompt(nil)
            await flushAppBindings()
            XCTAssertNil(state.alertDeliveryPrompt)
        }
    }

    func testExpandingAnAlertConsumesTheScrollRequestAndRetainsTheExpandedSection() async throws {
        let fixture = AlertBuilderFixture()
        defer { fixture.close() }
        let alert = AlertType.temperature(lower: 0, upper: 20)
        fixture.configure(alert, lower: 0, upper: 20)
        let section = try XCTUnwrap(fixture.section(alert))
        let state = CardsSettingsState(
            snapshot: fixture.measurements.snapshot, measurementService: fixture.measurements.measurement)
        state.setAlertSections([section])
        let view = UIHostingController(
            rootView: CardsAlertsView(state: state, displayMode: .alerts, onAlertDeliveryPromptTap: { _ in }))
        let host = try AppViewHost(view)
        defer { host.close() }
        await waitForAppState("alert sections attached and rendered") {
            view.view.layoutIfNeeded()
            return view.view.window === host.window && view.view.bounds.height > 0
                && view.view.allDescendants.contains { $0 is UIScrollView }
        }
        await flushAppBindings()
        state.toggleAlertSection(section.id)
        await waitForAppState("expanded alert scrolled into view") { state.lastExpandedAlertID == nil }
        XCTAssertTrue(state.isAlertSectionExpanded(section.id))
        state.toggleAlertSection(section.id)
        await flushAppBindings()
        XCTAssertFalse(state.isAlertSectionExpanded(section.id))
        XCTAssertNil(state.lastExpandedAlertID)
    }
}
