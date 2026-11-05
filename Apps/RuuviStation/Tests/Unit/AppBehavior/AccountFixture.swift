import Foundation
import RuuviCloud
import RuuviCore
import RuuviOntology
import RuuviPresenters
import RuuviService
@testable import station

@MainActor final class AccountFixture {
    let cloud = AppCloudSpy()
    let user = DefaultsUserSpy()
    let settings = AppTestSettings()
    let flags = AppTestFlags()
    let view = AccountViewSpy()
    let router = AccountRouterSpy()
    let activity = AccountActivitySpy()
    let errors = OffsetErrorSpy()
    let alerts = GraphAlertSpy()
    let auth = AccountAuthSpy()
    let push = AccountPushSpy()
    let notification = AccountNotificationSpy()
    let mail = AccountMailSpy()
    let appSettings: AppSettingsServiceSpy
    var widgets = [String]()
    var presenter: MyRuuviAccountPresenter!
    init() {
        appSettings = AppSettingsServiceSpy(settings: settings)
        presenter = MyRuuviAccountPresenter()
        presenter.view = view
        presenter.router = router
        presenter.ruuviCloud = cloud
        presenter.ruuviUser = user
        presenter.authService = auth
        presenter.alertPresenter = alerts
        presenter.errorPresenter = errors
        presenter.activityPresenter = activity
        presenter.pnManager = push
        presenter.cloudNotificationService = notification
        presenter.ruuviAppSettingsService = appSettings
        presenter.settings = settings
        presenter.flags = flags
        presenter.mailComposerPresenter = mail
        presenter.reloadWidget = { [weak self] in self?.widgets.append($0) }
        user.email = "OWNER@example.com"
        user.isAuthorized = true
        flags.showMarketingPreference = true
        appSettings.onGetMarketing = { .init(consent: false, status: .unsubscribed) }
    }
}
final class AccountViewSpy: MyRuuviAccountViewInput {
    var viewModel: MyRuuviAccountViewModel?
    var deletions = 0
    var confirmations = 0
    func viewDidShowAccountDeletionConfirmation() { deletions += 1 }
    func viewDidReceiveUnconfirmedMarketingConsent() { confirmations += 1 }
}
final class AccountRouterSpy: MyRuuviAccountRouterInput {
    var dismissals = 0
    func dismiss() { dismissals += 1 }
}
final class AccountMailSpy: MailComposerPresenter {
    var emails = [String]()
    func present(email: String) { emails.append(email) }
    func present(email: String, subject: String, body: String?) { emails.append(email) }
}
final class AccountActivitySpy: ActivityPresenter {
    var shown = [ActivityPresenterState]()
    var updates = [ActivityPresenterState]()
    var dismissals = [Bool]()
    func show(with state: ActivityPresenterState, atPosition position: ActivityPresenterPosition) {
        shown.append(state)
    }
    func update(with state: ActivityPresenterState) { updates.append(state) }
    func dismiss(immediately: Bool) { dismissals.append(immediately) }
}
@MainActor final class AccountAuthSpy: RuuviServiceAuth {
    var calls = 0
    var beforeLogout: (() async -> Void)?
    var failure: RuuviServiceError?
    func logout() async throws(RuuviServiceError) -> Bool {
        calls += 1
        await beforeLogout?()
        if let failure { throw failure }
        return true
    }
}
final class AccountPushSpy: RuuviCorePN {
    var pnTokenData: Data?
    var fcmToken: String?
    var fcmTokenId: Int?
    var fcmTokenLastRefreshed: Date?
    func registerForRemoteNotifications() {}
    func getRemoteNotificationsAuthorizationStatus(completion: @escaping (PNAuthorizationStatus) -> Void) {
        completion(.denied)
    }
}
@MainActor final class AccountNotificationSpy: RuuviServiceCloudNotification {
    var unregisters = [String?]()
    var beforeUnregister: (() async -> Void)?
    var failure: RuuviServiceError?
    func unregister(token: String?, tokenId: Int?) async throws(RuuviServiceError) -> Bool {
        unregisters.append(token)
        await beforeUnregister?()
        if let failure { throw failure }
        return true
    }
    func set(token: String?, name: String?, data: String?, language: Language, sound: RuuviAlertSound)
        async throws(RuuviServiceError) -> Int
    { throw .failedToParseNetworkResponse }
    func set(sound: RuuviAlertSound, language: Language, deviceName: String?) async throws(RuuviServiceError) -> Int {
        throw .failedToParseNetworkResponse
    }
    func register(token: String, type: String, name: String?, data: String?, params: [String: String]?)
        async throws(RuuviServiceError) -> Int
    { throw .failedToParseNetworkResponse }
    func listTokens() async throws(RuuviServiceError) -> [RuuviCloudPNToken] { throw .failedToParseNetworkResponse }
}
