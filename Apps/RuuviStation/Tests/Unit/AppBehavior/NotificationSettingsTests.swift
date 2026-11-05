import Foundation
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class NotificationSettingsTests: XCTestCase {
    func testAuthorizationControlsCloudRowsAndTogglesPersistTheCorrectDisabledFlags() async throws {
        let fixture = NotificationSettingsFixture()
        fixture.presenter.viewDidLoad()
        XCTAssertEqual(fixture.view.viewModels.map { $0.settingsType.value }, [.limitAlert, .alertSound])
        fixture.user.isAuthorized = true
        fixture.settings.showSwitchStatusLabel = true
        fixture.presenter.viewDidLoad()
        XCTAssertEqual(
            fixture.view.viewModels.map { $0.settingsType.value }, [.limitAlert, .email, .push, .alertSound])
        let email = try XCTUnwrap(fixture.view.viewModels.first { $0.settingsType.value == .email })
        let push = try XCTUnwrap(fixture.view.viewModels.first { $0.settingsType.value == .push })
        let limit = try XCTUnwrap(fixture.view.viewModels.first { $0.settingsType.value == .limitAlert })
        XCTAssertEqual(email.hideStatusLabel.value, false)
        XCTAssertEqual(push.hideStatusLabel.value, false)
        for enabled in [false, true] {
            let count = fixture.service.calls.count
            email.boolean.value = enabled
            push.boolean.value = enabled
            limit.boolean.value = enabled
            await waitForAppState("notification preferences saved") { fixture.service.calls.count == count + 2 }
            XCTAssertEqual(fixture.settings.emailAlertDisabled, !enabled)
            XCTAssertEqual(fixture.settings.pushAlertDisabled, !enabled)
            XCTAssertEqual(fixture.settings.limitAlertNotificationsEnabled, enabled)
            XCTAssertEqual(Set(fixture.service.calls.suffix(2)), Set(["disableEmailAlert", "disablePushAlert"]))
        }
    }

    func testExternalPushAndEmailUpdatesRemainIndependent() throws {
        let fixture = NotificationSettingsFixture()
        fixture.user.isAuthorized = true
        fixture.presenter.viewDidLoad()
        fixture.settings.emailAlertDisabled = false
        fixture.settings.pushAlertDisabled = true
        fixture.notifications.post(name: .PushAlertSettingsDidChange, object: nil)
        XCTAssertEqual(fixture.row(.push)?.boolean.value, false)
        XCTAssertEqual(fixture.row(.email)?.boolean.value, true)
        fixture.settings.emailAlertDisabled = true
        fixture.notifications.post(name: .EmailAlertSettingsDidChange, object: nil)
        XCTAssertEqual(fixture.row(.email)?.boolean.value, false)
        XCTAssertEqual(fixture.row(.push)?.boolean.value, false)
        fixture.settings.pushAlertDisabled = false
        fixture.notifications.post(name: .PushAlertSettingsDidChange, object: nil)
        XCTAssertEqual(fixture.row(.push)?.boolean.value, true)
        XCTAssertEqual(fixture.row(.email)?.boolean.value, false)
    }

    func testSoundSelectionAndNotificationsUploadOnceAfterRepeatedViewLoading() async throws {
        let fixture = NotificationSettingsFixture()
        fixture.presenter.viewDidLoad()
        fixture.presenter.viewDidLoad()
        fixture.settings.alertSound = .ruuviSpeak
        fixture.presenter.viewDidTapSoundSelection()
        let selection = try XCTUnwrap(fixture.router.model)
        XCTAssertEqual(selection.selection as? RuuviAlertSound, .ruuviSpeak)
        XCTAssertEqual(selection.items.count, 2)
        fixture.notifications.post(name: .AlertSoundSettingsDidChange, object: nil)
        await waitForAppState("sound preference uploaded") { !fixture.cloud.sounds.isEmpty }
        await Task.yield()
        XCTAssertEqual(fixture.cloud.sounds.count, 1)
        XCTAssertEqual(fixture.cloud.sounds.first, .ruuviSpeak)
        XCTAssertEqual(fixture.cloud.languages.first, fixture.settings.language)
        XCTAssertEqual(fixture.row(.alertSound)?.value.value, RuuviAlertSound.ruuviSpeak.title(""))
    }
}

@MainActor private final class NotificationSettingsFixture {
    let settings = AppTestSettings()
    let user = DefaultsUserSpy()
    let view = NotificationSettingsViewSpy()
    let router = NotificationSettingsRouterSpy()
    let cloud = NotificationSettingsCloudSpy()
    let notifications = NotificationCenter()
    let service: AppSettingsServiceSpy
    let presenter: NotificationsSettingsPresenter
    init() {
        service = AppSettingsServiceSpy(settings: settings)
        presenter = NotificationsSettingsPresenter(notificationCenter: notifications)
        presenter.settings = settings
        presenter.ruuviUser = user
        presenter.ruuviAppSettingsService = service
        presenter.cloudNotificationService = cloud
        presenter.view = view
        presenter.router = router
    }
    func row(_ type: NotificationsSettingsType) -> NotificationsSettingsViewModel? {
        view.viewModels.first { $0.settingsType.value == type }
    }
}

private final class NotificationSettingsViewSpy: NotificationsSettingsViewInput {
    var viewModels = [NotificationsSettingsViewModel]()
}

private final class NotificationSettingsRouterSpy: NotificationsSettingsRouterInput {
    var model: PushAlertSoundSelectionViewModel?
    func dismiss() {}
    func openSelection(with viewModel: PushAlertSoundSelectionViewModel) { model = viewModel }
}

private final class NotificationSettingsCloudSpy: RuuviServiceCloudNotification {
    var sounds = [RuuviAlertSound]()
    var languages = [Language]()
    func set(sound: RuuviAlertSound, language: Language, deviceName: String?) async throws(RuuviServiceError) -> Int {
        sounds.append(sound)
        languages.append(language)
        return 1
    }
    func set(token: String?, name: String?, data: String?, language: Language, sound: RuuviAlertSound)
        async throws(RuuviServiceError) -> Int
    { throw .failedToParseNetworkResponse }
    func register(token: String, type: String, name: String?, data: String?, params: [String: String]?)
        async throws(RuuviServiceError) -> Int
    { throw .failedToParseNetworkResponse }
    func unregister(token: String?, tokenId: Int?) async throws(RuuviServiceError) -> Bool { true }
    func listTokens() async throws(RuuviServiceError) -> [RuuviCloudPNToken] { [] }
}
