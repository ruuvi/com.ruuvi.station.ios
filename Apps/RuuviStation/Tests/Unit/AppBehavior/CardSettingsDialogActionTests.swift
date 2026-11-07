import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class CardSettingsDialogActionTests: XCTestCase {
    func testRenamingAndDescriptionCommitOnlyConfirmedValuesAndKeepEmptyValueSemantics() async throws {
        let fixture = try CardSettingsViewFixture()
        defer { fixture.close() }
        let actions = AlertActionRecorder()
        fixture.view.alertActions = actions.factory
        for (text, confirm) in [("Kitchen 🌿", false), ("Kitchen 🌿", true), ("", true)] {
            actions.reset()
            fixture.actions.didTapSnapshotName.send()
            let alert = try await fixture.alert()
            let field = try XCTUnwrap(alert.textFields?.first)
            field.text = text
            let before = fixture.output.names.count
            try actions.invoke(confirm ? RuuviLocalization.ok : RuuviLocalization.cancel)
            XCTAssertEqual(fixture.output.names.count, before + (confirm ? 1 : 0))
            if confirm { XCTAssertEqual(fixture.output.names.last, text.isEmpty ? field.placeholder : text) }
            await fixture.dismissAlert()
        }
        for text in ["  Door open 🌿  ", " \n "] {
            actions.reset()
            fixture.actions.didRequestAlertDescriptionEdit.send(fixture.temperature)
            let alert = try await fixture.alert()
            alert.textFields?.first?.text = text
            try actions.invoke(RuuviLocalization.ok)
            XCTAssertEqual(fixture.output.descriptions.last?.0.rawValue, fixture.temperature.rawValue)
            XCTAssertEqual(
                fixture.output.descriptions.last?.1,
                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "Door open 🌿")
            await fixture.dismissAlert()
        }
    }

    func testManualRangesRejectMissingReversedAndOutOfBoundsValuesAndAcceptDecimals() async throws {
        let fixture = try CardSettingsViewFixture()
        defer { fixture.close() }
        let actions = AlertActionRecorder()
        fixture.view.alertActions = actions.factory
        for (lower, upper) in [("", "20"), ("bad", "20"), ("10", "10"), ("20", "10"), ("-9999", "9999")] {
            actions.reset()
            fixture.actions.didRequestAlertLimitEdit.send(fixture.temperature)
            let alert = try await fixture.alert()
            alert.textFields?.first?.text = lower
            alert.textFields?.last?.text = upper
            try actions.invoke(RuuviLocalization.ok)
            XCTAssertTrue(fixture.output.lower.isEmpty)
            XCTAssertTrue(fixture.output.upper.isEmpty)
            await fixture.dismissAlert()
        }
        actions.reset()
        fixture.actions.didRequestAlertLimitEdit.send(fixture.temperature)
        let alert = try await fixture.alert()
        let separator = Locale.current.decimalSeparator ?? "."
        alert.textFields?.first?.text = " 5" + separator + "25 "
        alert.textFields?.last?.text = "24" + separator + "75"
        try actions.invoke(RuuviLocalization.ok)
        XCTAssertEqual(fixture.output.lower.map(\.1), [5.25])
        XCTAssertEqual(fixture.output.upper.map(\.1), [24.75])
    }

    func testCloudDelayCommitsSecondsOnlyWhenChangedAndCancellationResetsTheEditor() async throws {
        let fixture = try CardSettingsViewFixture()
        defer { fixture.close() }
        let actions = AlertActionRecorder()
        fixture.view.alertActions = actions.factory
        for (minutes, confirm) in [(15, true), (20, false), (20, true)] {
            actions.reset()
            fixture.actions.didTapCloudConnectionDelay.send()
            let alert = try await fixture.alert()
            let field = try XCTUnwrap(alert.textFields?.first)
            field.text = String(minutes)
            field.sendActions(for: .editingChanged)
            try actions.invoke(confirm ? RuuviLocalization.ok : RuuviLocalization.cancel)
            await fixture.dismissAlert()
        }
        XCTAssertEqual(fixture.output.delays, [1200])
        actions.reset()
        fixture.actions.didTapCloudConnectionDelay.send()
        let alert = try await fixture.alert()
        let field = try XCTUnwrap(alert.textFields?.first)
        let confirm = try XCTUnwrap(alert.actions.first { $0.title == RuuviLocalization.ok })
        field.text = String(Int.max)
        field.sendActions(for: .editingChanged)
        XCTAssertFalse(confirm.isEnabled, "Minutes that overflow conversion to seconds must be rejected")
        field.text = String(Int.max / 60)
        field.sendActions(for: .editingChanged)
        XCTAssertTrue(confirm.isEnabled)
    }

    func testOwnershipAndFirmwareActionsPreserveConfirmAndCancelDecisions() async throws {
        let fixture = try CardSettingsViewFixture()
        defer { fixture.close() }
        let actions = AlertActionRecorder()
        fixture.view.alertActions = actions.factory
        fixture.view.showTagClaimDialog()
        _ = try await fixture.alert()
        try actions.invoke(RuuviLocalization.no)
        XCTAssertTrue(fixture.output.events.isEmpty)
        await fixture.dismissAlert()
        actions.reset()
        fixture.view.showTagClaimDialog()
        _ = try await fixture.alert()
        try actions.invoke(RuuviLocalization.yes)
        XCTAssertEqual(fixture.output.events, ["claim"])
        await fixture.dismissAlert()
        actions.reset()
        fixture.view.showFirmwareUpdateDialog()
        _ = try await fixture.alert()
        try actions.invoke(RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title)
        await fixture.dismissAlert()
        actions.reset()
        fixture.view.showFirmwareUpdateDialog()
        _ = try await fixture.alert()
        try actions.invoke(RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title)
        XCTAssertEqual(fixture.output.events, ["claim", "ignore-firmware", "confirm-firmware"])
        await fixture.dismissAlert()
        actions.reset()
        fixture.view.showFirmwareDismissConfirmationUpdateDialog()
        _ = try await fixture.alert()
        try actions.invoke(RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title)
        XCTAssertEqual(fixture.output.events.last, "confirm-firmware")
    }
}
