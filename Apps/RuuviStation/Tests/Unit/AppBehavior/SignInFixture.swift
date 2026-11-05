import Foundation
import RuuviCloud
import RuuviDaemon
import RuuviOntology
import RuuviPresenters
import RuuviService
@testable import station

@MainActor final class SignInFixture {
    let cloud = AppCloudSpy()
    let user = DefaultsUserSpy()
    let settings = AppTestSettings()
    let view = SignInViewSpy()
    let router = SignInRouterSpy()
    let activity = SignInActivitySpy()
    let errors = OffsetErrorSpy()
    let output = SignInOutputSpy()
    let sync = SignInSyncSpy()
    let daemon = SignInDaemonSpy()
    let notification = SignInNotificationSpy()
    let auth = SignInAuthSpy()
    let notifications = NotificationCenter()
    var widgetKinds = [String]()
    var tokenRequests = 0
    var presenter: SignInPresenter!

    init(state: SignInPresenter.State = .enterEmail) {
        presenter = SignInPresenter(notificationCenter: notifications)
        presenter.view = view
        presenter.router = router
        presenter.activityPresenter = activity
        presenter.errorPresenter = errors
        presenter.ruuviUser = user
        presenter.ruuviCloud = cloud
        presenter.cloudSyncService = sync
        presenter.cloudSyncDaemon = daemon
        presenter.cloudNotificationService = notification
        presenter.authService = auth
        presenter.settings = settings
        presenter.reloadWidget = { [weak self] in self?.widgetKinds.append($0) }
        presenter.requestFCMToken = { [weak self] callback in
            self?.tokenRequests += 1; callback("fixture-token")
        }
        presenter.configure(with: state, output: output)
    }
    func readyToVerify() {
        user.email = "owner@example.com"
        cloud.onValidateCode = { _ in .init(email: "OWNER@example.com", apiKey: "validated-key") }
        presenter.configure(with: .enterVerificationCode(nil), output: output)
        presenter.viewDidLoad()
    }
}

final class SignInViewSpy: SignInViewInput {
    var viewModel: SignInViewModel!
    var fromDeepLink = false
    var mismatches = [(String, String)]()
    var missingEmail = 0
    var invalidTokens = 0
    var invalidEmails = 0
    var unexpectedStatuses = 0
    func showEmailsAreDifferent(requestedEmail: String, validatedEmail: String) {
        mismatches.append((requestedEmail, validatedEmail))
    }
    func showFailedToGetRequestedEmail() { missingEmail += 1 }
    func showInvalidTokenEntered() { invalidTokens += 1 }
    func showInvalidEmailEntered() { invalidEmails += 1 }
    func showUnexpectedHTTPStatusCodeError() { unexpectedStatuses += 1 }
}

final class SignInRouterSpy: SignInRouterInput {
    var dismissals = 0
    var pops = [Bool]()
    var promos = 0
    func dismiss(completion: (() -> Void)?) { dismissals += 1; completion?() }
    func popViewController(animated: Bool, completion: (() -> Void)?) { pops.append(animated); completion?() }
    func openSignInPromoViewController(output: SignInBenefitsModuleOutput) { promos += 1 }
}

final class SignInActivitySpy: ActivityPresenter {
    var shown = 0
    var dismissed = 0
    func show(with state: ActivityPresenterState, atPosition position: ActivityPresenterPosition) { shown += 1 }
    func update(with state: ActivityPresenterState) {}
    func dismiss(immediately: Bool) { dismissed += 1 }
}

final class SignInOutputSpy: SignInModuleOutput {
    var logins = 0
    var closes = 0
    var skips = 0
    func signIn(module: SignInModuleInput, didSuccessfulyLogin sender: Any?) { logins += 1 }
    func signIn(module: SignInModuleInput, didCloseSignInWithoutAttempt sender: Any?) { closes += 1 }
    func signIn(module: SignInModuleInput, didSelectUseWithoutAccount sender: Any?) { skips += 1 }
}

final class SignInSyncSpy: RuuviServiceCloudSync {
    var historyCalls = 0
    var latestCalls = 0
    var historyError: RuuviServiceError?
    var latestError: RuuviServiceError?
    var beforeHistory: (() async -> Void)?
    func syncAllRecords() async throws(RuuviServiceError) -> Bool {
        historyCalls += 1
        await beforeHistory?()
        if let historyError { throw historyError }
        return true
    }
    func refreshLatestRecord() async throws(RuuviServiceError) -> Bool {
        latestCalls += 1
        if let latestError { throw latestError }
        return true
    }
    func sync(sensor: RuuviTagSensor) async throws(RuuviServiceError) -> [AnyRuuviTagSensorRecord] { [] }
    func syncAll() async throws(RuuviServiceError) -> Set<AnyRuuviTagSensor> { [] }
    func syncAllHistory() async throws(RuuviServiceError) -> Bool { true }
    func syncSettings() async throws(RuuviServiceError) -> RuuviCloudSettings { throw .failedToParseNetworkResponse }
    func executePendingRequests() async throws(RuuviServiceError) -> Bool { true }
}

final class SignInDaemonSpy: RuuviDaemonCloudSync {
    var starts = 0
    var stops = 0
    func start() { starts += 1 }
    func stop() { stops += 1 }
    func isRunning() -> Bool { starts > stops }
    func refreshImmediately() {}
    func refreshLatestRecord() {}
}

final class SignInNotificationSpy: RuuviServiceCloudNotification {
    var tokens = [String?]()
    var languages = [Language]()
    var sounds = [RuuviAlertSound]()
    func set(token: String?, name: String?, data: String?, language: Language, sound: RuuviAlertSound)
        async throws(RuuviServiceError) -> Int
    {
        tokens.append(token); languages.append(language); sounds.append(sound)
        return 1
    }
    func set(sound: RuuviAlertSound, language: Language, deviceName: String?) async throws(RuuviServiceError) -> Int {
        1
    }
    func register(token: String, type: String, name: String?, data: String?, params: [String: String]?)
        async throws(RuuviServiceError) -> Int
    { 1 }
    func unregister(token: String?, tokenId: Int?) async throws(RuuviServiceError) -> Bool { true }
    func listTokens() async throws(RuuviServiceError) -> [RuuviCloudPNToken] { [] }
}

final class SignInAuthSpy: RuuviServiceAuth {
    var logouts = 0
    var failure: RuuviServiceError?
    func logout() async throws(RuuviServiceError) -> Bool {
        logouts += 1
        if let failure { throw failure }
        return true
    }
}
