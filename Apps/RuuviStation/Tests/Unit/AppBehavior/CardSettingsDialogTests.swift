import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class CardSettingsDialogTests: XCTestCase {
    func testOwnershipFirmwareAndConnectionPromptsExplainTheirChoicesBeforeAnyAction() async throws {
        let fixture = try CardSettingsViewFixture()
        defer { fixture.close() }
        fixture.view.showTagClaimDialog()
        var alert = try await fixture.alert()
        XCTAssertEqual(alert.title, RuuviLocalization.claimSensorOwnership)
        XCTAssertEqual(alert.message, RuuviLocalization.doYouOwnSensor)
        XCTAssertEqual(alert.actions.map(\.title), [RuuviLocalization.yes, RuuviLocalization.no])
        XCTAssertEqual(alert.actions.map(\.style), [.default, .cancel])
        await fixture.dismissAlert()
        fixture.view.showFirmwareUpdateDialog()
        alert = try await fixture.alert()
        XCTAssertEqual(alert.message, RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.message)
        XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default])
        await fixture.dismissAlert()
        fixture.view.showFirmwareDismissConfirmationUpdateDialog()
        alert = try await fixture.alert()
        XCTAssertEqual(alert.message, RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message)
        XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default])
        await fixture.dismissAlert()
        fixture.view.showKeepConnectionTimeoutDialog()
        alert = try await fixture.alert()
        XCTAssertEqual(alert.message, RuuviLocalization.TagSettings.PairError.Timeout.description)
        XCTAssertEqual(alert.actions.map(\.title), [RuuviLocalization.ok])
        await fixture.dismissAlert()
        fixture.view.showKeepConnectionCloudModeDialog()
        alert = try await fixture.alert()
        XCTAssertEqual(alert.message, RuuviLocalization.TagSettings.PairError.CloudMode.description)
        XCTAssertEqual(alert.actions.map(\.style), [.cancel])
        XCTAssertTrue(fixture.output.events.isEmpty)
        XCTAssertTrue(fixture.output.keep.isEmpty)
    }

    func testMacDetailsShowTheConfiguredIdentityAndOfferCopyOrCancel() async throws {
        let fixture = try CardSettingsViewFixture()
        defer { fixture.close() }
        fixture.view.showMacAddressDetail()
        let alert = try await fixture.alert()
        XCTAssertEqual(alert.title, RuuviLocalization.TagSettings.Mac.Alert.title)
        XCTAssertEqual(alert.message, fixture.builder.measurements.sensor.macId?.value)
        XCTAssertEqual(alert.actions.map(\.title), [RuuviLocalization.copy, RuuviLocalization.cancel])
        XCTAssertEqual(alert.actions.map(\.style), [.default, .cancel])
    }
}
