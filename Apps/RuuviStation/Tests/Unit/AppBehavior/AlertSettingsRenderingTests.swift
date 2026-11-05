import Foundation
import RangeSeekSlider
import RuuviOntology
import SwiftUI
import UIKit
import Vision
import XCTest
@testable import station

@MainActor final class AlertSettingsRenderingTests: XCTestCase {
    func testExpandedAlertRowsRenderAndForwardToggleAndSliderEditsInBothSettingsLayouts() async throws {
        let fixture = AlertBuilderFixture()
        defer { fixture.close() }
        let cases: [AlertType] = [
            .temperature(lower: 0, upper: 20), .aqi(lower: 20, upper: 80), .movement(last: 1),
            .connection, .cloudConnection(unseenDuration: 900), .soundInstant(lower: 20, upper: 50),
        ]
        for mode: CardsSettingsAlertDisplayMode in [.legacySettings, .alerts] {
            for (index, alert) in cases.enumerated() {
                fixture.configure(alert, lower: nil, upper: nil)
                let section = try XCTUnwrap(fixture.section(alert))
                var toggles = [Bool]()
                var changes = [(ClosedRange<Double>, Bool)]()
                let root = CardsSettingsAlertSectionRow(
                    model: section, isExpanded: true, showsToggleInHeader: true, displayMode: mode,
                    onToggleSection: {}, onToggleAlert: { toggles.append($0) },
                    onRangeChange: { changes.append(($0, $1)) }, onEditDescription: {},
                    onTapLimitEdit: {}, onTapCloudDelay: {})
                let host = UIHostingController(rootView: ScrollView { root })
                host.overrideUserInterfaceStyle = mode == .alerts ? .dark : .light
                let scene = try XCTUnwrap(
                    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: 393, height: 640)
                window.rootViewController = host
                window.isHidden = false
                defer { window.isHidden = true; window.rootViewController = nil }
                host.loadViewIfNeeded()
                host.view.frame = window.bounds
                host.view.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(50))
                host.view.layoutIfNeeded()
                let toggle = try XCTUnwrap(host.view.allDescendants.compactMap { $0 as? UISwitch }.first)
                XCTAssertTrue(toggle.isOn)
                XCTAssertTrue(toggle.isEnabled)
                toggle.setOn(false, animated: false)
                toggle.sendActions(for: .valueChanged)
                XCTAssertEqual(toggles, [false], "One control event must create one settings command")
                let sliders = host.view.allDescendants.compactMap { $0 as? RangeSeekSlider }
                if let configuration = section.configuration.sliderConfiguration {
                    let slider = try XCTUnwrap(sliders.first)
                    XCTAssertEqual(Double(slider.minValue), configuration.range.lowerBound, accuracy: 0.001)
                    XCTAssertEqual(Double(slider.maxValue), configuration.range.upperBound, accuracy: 0.001)
                    let lower =
                        configuration.range.lowerBound
                        + (configuration.range.upperBound - configuration.range.lowerBound) * 0.25
                    let upper =
                        configuration.range.lowerBound
                        + (configuration.range.upperBound - configuration.range.lowerBound) * 0.75
                    slider.selectedMinValue = CGFloat(lower)
                    slider.selectedMaxValue = CGFloat(upper)
                    slider.delegate?.rangeSeekSlider(slider, didChange: CGFloat(lower), maxValue: CGFloat(upper))
                    slider.delegate?.didEndTouches(in: slider)
                    XCTAssertEqual(changes.map(\.1), [false, true])
                    XCTAssertEqual(changes.last?.0.lowerBound ?? -1, lower, accuracy: 0.001)
                    XCTAssertEqual(changes.last?.0.upperBound ?? -1, upper, accuracy: 0.001)
                } else {
                    XCTAssertTrue(sliders.isEmpty)
                    XCTAssertTrue(changes.isEmpty)
                }
                if index == 0 || index == 4 {
                    let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image {
                        host.view.layer.render(in: $0.cgContext)
                    }
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
                    let strings = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
                    XCTAssertFalse(strings.isEmpty, "The alert controls must have visible text")
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "Alert settings \(mode) \(alert.rawValue)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }

    func testUpdatedSliderConfigurationChangesTheDisplayedLimitsAndUsesTheNewCallbacks() async throws {
        var oldChanges = 0
        var changes = [(Double, Double)]()
        let initial = CardsSettingsAlertSliderConfiguration(
            range: 0...100, selectedRange: 20...80, unit: "%", format: "%.0f")
        let host = UIHostingController(
            rootView: CardsSettingsAlertRangeSliderView(
                configuration: initial, onRangeChange: { _, _ in oldChanges += 1 }, onRangeChangeEnd: { _, _ in }))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 150)
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
        let revised = CardsSettingsAlertSliderConfiguration(
            range: -10...200, selectedRange: -100...300, unit: "ppm", format: "%.1f",
            step: 0.5, minDistance: 5, lineHeight: 5, handleDiameter: 24, enableStep: false, hideLabels: false)
        host.rootView = CardsSettingsAlertRangeSliderView(
            configuration: revised, onRangeChange: { changes.append(($0, $1)) }, onRangeChangeEnd: { _, _ in })
        try await Task.sleep(for: .milliseconds(50))
        host.view.layoutIfNeeded()
        let slider = try XCTUnwrap(host.view.allDescendants.compactMap { $0 as? RangeSeekSlider }.first)
        XCTAssertEqual(slider.selectedMinValue, -10)
        XCTAssertEqual(slider.selectedMaxValue, 200)
        XCTAssertEqual(slider.step, 0.5)
        XCTAssertEqual(slider.minDistance, 5)
        XCTAssertEqual(slider.handleDiameter, 24)
        XCTAssertEqual(slider.lineHeight, 5)
        XCTAssertFalse(slider.enableStep)
        XCTAssertFalse(slider.hideLabels)
        slider.delegate?.rangeSeekSlider(slider, didChange: 10, maxValue: 100)
        XCTAssertEqual(oldChanges, 0)
        XCTAssertEqual(changes.map(\.0), [10])
        XCTAssertEqual(changes.map(\.1), [100])
    }
}
