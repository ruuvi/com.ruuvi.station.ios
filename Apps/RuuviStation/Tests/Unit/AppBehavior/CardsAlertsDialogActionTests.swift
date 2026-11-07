import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class CardsAlertsDialogActionTests: XCTestCase {
    func testDescriptionConfirmationTrimsWhitespaceAndCancelLeavesTheExistingDescription() async throws {
        let fixture = CardsAlertsScreenFixture()
        defer { fixture.cleanup() }
        try fixture.start()
        let actions = AlertActionRecorder()
        fixture.view.alertActions = actions.factory
        for (text, confirm) in [("  New note 🌿  ", false), ("  New note 🌿  ", true), (" \n ", true)] {
            actions.reset()
            fixture.actions.didRequestAlertDescriptionEdit.send(fixture.type)
            let alert = try await fixture.alert()
            alert.textFields?.first?.text = text
            let previous = fixture.output.descriptions.count
            try actions.invoke(confirm ? RuuviLocalization.ok : RuuviLocalization.cancel)
            XCTAssertEqual(fixture.output.descriptions.count, previous + (confirm ? 1 : 0))
            if confirm {
                XCTAssertEqual(fixture.output.descriptions.last?.0, fixture.type.rawValue)
                XCTAssertEqual(fixture.output.descriptions.last?.1, text == " \n " ? nil : "New note 🌿")
            }
            await fixture.dismiss()
        }
    }

    func testManualAlertRangeRejectsInvalidLimitsAndCommitsValidDecimals() async throws {
        let fixture = CardsAlertsScreenFixture()
        defer { fixture.cleanup() }
        try fixture.start()
        let actions = AlertActionRecorder()
        fixture.view.alertActions = actions.factory
        for (lower, upper) in [("bad", "10"), ("10", "10"), ("20", "10"), ("-9999", "9999")] {
            actions.reset()
            fixture.actions.didRequestAlertLimitEdit.send(fixture.type)
            let alert = try await fixture.alert()
            alert.textFields?.first?.text = lower
            alert.textFields?.last?.text = upper
            try actions.invoke(RuuviLocalization.ok)
            XCTAssertTrue(fixture.output.lowers.isEmpty)
            XCTAssertTrue(fixture.output.uppers.isEmpty)
            await fixture.dismiss()
        }
        actions.reset()
        fixture.actions.didRequestAlertLimitEdit.send(fixture.type)
        let alert = try await fixture.alert()
        let separator = Locale.current.decimalSeparator ?? "."
        alert.textFields?.first?.text = "5" + separator + "25"
        alert.textFields?.last?.text = "24" + separator + "75"
        try actions.invoke(RuuviLocalization.ok)
        XCTAssertEqual(fixture.output.lowers.map(\.1), [5.25])
        XCTAssertEqual(fixture.output.uppers.map(\.1), [24.75])
    }

    func testCloudDelayRequiresConfirmationAndRejectsOverflowEvenBeforeAnEditingEvent() async throws {
        let fixture = CardsAlertsScreenFixture()
        defer { fixture.cleanup() }
        try fixture.start()
        let actions = AlertActionRecorder()
        fixture.view.alertActions = actions.factory
        for (minutes, confirm) in [(String(Int.max), true), ("15", true), ("20", false), ("20", true)] {
            actions.reset()
            fixture.actions.didTapCloudConnectionDelay.send()
            let alert = try await fixture.alert()
            let field = try XCTUnwrap(alert.textFields?.first)
            field.text = minutes
            try actions.invoke(confirm ? RuuviLocalization.ok : RuuviLocalization.cancel)
            await fixture.dismiss()
        }
        XCTAssertEqual(fixture.output.delays, [1200])
        actions.reset()
        fixture.actions.didTapCloudConnectionDelay.send()
        let alert = try await fixture.alert()
        let field = try XCTUnwrap(alert.textFields?.first)
        field.text = String(Int.max)
        field.sendActions(for: .editingChanged)
        XCTAssertEqual(alert.actions.first?.isEnabled, false)
        field.text = String(Int.max / 60)
        field.sendActions(for: .editingChanged)
        XCTAssertEqual(alert.actions.first?.isEnabled, true)
    }
}
