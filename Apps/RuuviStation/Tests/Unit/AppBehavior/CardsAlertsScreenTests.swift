import Foundation
import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class CardsAlertsScreenTests: XCTestCase {
    func testAlertControlsForwardTogglesAndOnlyChangedFinalRangeValues() async throws {
        let fixture = CardsAlertsScreenFixture()
        defer { fixture.cleanup() }
        try fixture.start()
        XCTAssertEqual(fixture.output.loads, 1)
        await waitForAppState("alert screen appeared") { fixture.output.appearances == 1 }
        XCTAssertEqual(fixture.output.appearances, 1)
        fixture.actions.didToggleAlert.send((fixture.type, false))
        XCTAssertEqual(fixture.output.states.map(\.0), [fixture.type.rawValue])
        XCTAssertEqual(fixture.output.states.map(\.1), [false])
        fixture.actions.didChangeAlertRange.send(
            .init(alertType: fixture.type, lowerBound: 2, upperBound: 19, isFinal: false))
        XCTAssertTrue(fixture.output.lowers.isEmpty)
        fixture.actions.didChangeAlertRange.send(
            .init(alertType: fixture.type, lowerBound: 0, upperBound: 20, isFinal: true))
        XCTAssertTrue(fixture.output.lowers.isEmpty)
        fixture.actions.didChangeAlertRange.send(
            .init(alertType: fixture.type, lowerBound: 2, upperBound: 20, isFinal: true))
        XCTAssertEqual(fixture.output.lowers.map(\.1), [2])
        XCTAssertTrue(fixture.output.uppers.isEmpty)
        fixture.actions.didChangeAlertRange.send(
            .init(alertType: fixture.type, lowerBound: 0, upperBound: 18, isFinal: true))
        XCTAssertEqual(fixture.output.uppers.map(\.1), [18])
        fixture.actions.didChangeAlertRange.send(
            .init(alertType: fixture.type, lowerBound: 30, upperBound: 10, isFinal: true))
        XCTAssertEqual(fixture.output.lowers.count, 1)
        XCTAssertEqual(fixture.output.uppers.count, 1)
    }

    func testDescriptionEditorShowsCurrentTextAndEnforcesTheUtf16Limit() async throws {
        let fixture = CardsAlertsScreenFixture()
        defer { fixture.cleanup() }
        try fixture.start()
        fixture.actions.didRequestAlertDescriptionEdit.send(fixture.type)
        let alert = try await fixture.alert()
        let field = try XCTUnwrap(alert.textFields?.first)
        XCTAssertEqual(field.text, "Custom " + fixture.type.rawValue)
        XCTAssertEqual(alert.title, RuuviLocalization.TagSettings.Alert.CustomDescription.title)
        field.text = String(repeating: "a", count: 31)
        XCTAssertTrue(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 31, length: 0), replacementString: "b"))
        XCTAssertFalse(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 31, length: 0), replacementString: "😀"))
        XCTAssertTrue(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 0, length: 2), replacementString: "😀"))
        XCTAssertTrue(fixture.output.descriptions.isEmpty)
    }

    func testRangeEditorAllowsPastingValidDecimalsAndRejectsMalformedResultingNumbers() async throws {
        let fixture = CardsAlertsScreenFixture()
        defer { fixture.cleanup() }
        try fixture.start()
        fixture.actions.didRequestAlertLimitEdit.send(fixture.type)
        let alert = try await fixture.alert()
        XCTAssertEqual(alert.textFields?.count, 2)
        let field = try XCTUnwrap(alert.textFields?.first)
        let separator = Locale.current.decimalSeparator ?? "."
        XCTAssertNotNil(field.placeholder)
        field.text = ""
        XCTAssertTrue(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 0, length: 0),
                replacementString: "-12" + separator + "50"))
        field.text = "12" + separator + "34"
        XCTAssertFalse(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 5, length: 0), replacementString: "5"))
        XCTAssertTrue(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 3, length: 2), replacementString: "50"))
        XCTAssertFalse(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 5, length: 0), replacementString: separator))
        field.text = "12"
        XCTAssertFalse(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 2, length: 0), replacementString: "-"))
        XCTAssertFalse(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 0, length: 2), replacementString: "NaN"))
        XCTAssertTrue(fixture.output.lowers.isEmpty)
        XCTAssertTrue(fixture.output.uppers.isEmpty)
    }

    func testCloudDelayEditorValidatesMinutesBeforeEnablingSave() async throws {
        let fixture = CardsAlertsScreenFixture()
        defer { fixture.cleanup() }
        try fixture.start()
        fixture.actions.didTapCloudConnectionDelay.send()
        let alert = try await fixture.alert()
        let field = try XCTUnwrap(alert.textFields?.first)
        let save = try XCTUnwrap(alert.actions.first)
        XCTAssertEqual(field.text, "15")
        XCTAssertTrue(save.isEnabled)
        for invalid in ["", "0", "1", "x", "-2"] {
            field.text = invalid
            field.sendActions(for: .editingChanged)
            XCTAssertFalse(save.isEnabled, invalid)
        }
        field.text = "2"; field.sendActions(for: .editingChanged)
        XCTAssertTrue(save.isEnabled)
        XCTAssertFalse(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 1, length: 0), replacementString: "00"))
        XCTAssertFalse(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 1, length: 0), replacementString: "x"))
        XCTAssertTrue(
            fixture.view.textField(
                field, shouldChangeCharactersIn: NSRange(location: 0, length: 1), replacementString: "99"))
        XCTAssertTrue(fixture.output.delays.isEmpty)
    }
}
