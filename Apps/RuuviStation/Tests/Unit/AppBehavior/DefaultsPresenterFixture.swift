import Foundation
import RuuviLocal
import RuuviUser
@testable import station

@MainActor final class DefaultsPresenterFixture {
    let settings = AppTestSettings()
    let flags = AppTestFlags()
    let user = DefaultsUserSpy()
    let view = DefaultsViewSpy()
    let router = DefaultsRouterSpy()
    let output = DefaultsOutputSpy()
    let effects = DefaultsEffects()
    let suite = "DefaultsPresenterTests." + UUID().uuidString
    let defaults: UserDefaults
    let presenter: DefaultsPresenter

    init() {
        defaults = UserDefaults(suiteName: suite)!
        let effects = effects
        presenter = DefaultsPresenter(
            appGroupDefaults: defaults, notificationCenter: effects.notifications,
            reloadWidget: { effects.reloadedWidgets.append($0) })
        presenter.settings = settings
        presenter.flags = flags
        presenter.ruuviUser = user
        presenter.view = view
        presenter.router = router
    }

    deinit { defaults.removePersistentDomain(forName: suite) }
    func configure() { presenter.configure(output: output) }
}

final class DefaultsEffects {
    let notifications = NotificationCenter()
    var reloadedWidgets = [String]()
}

final class DefaultsViewSpy: DefaultsViewInput {
    var viewModels = [DefaultsViewModel]()
    var confirmations = [Bool?]()
    func showEndpointChangeConfirmationDialog(useDevServer: Bool?) { confirmations.append(useDevServer) }
}

final class DefaultsRouterSpy: DefaultsRouterInput {
    var dismissals = 0
    func dismiss() { dismissals += 1 }
}

final class DefaultsOutputSpy: DefaultsModuleOutput {
    var dismissals = 0
    func defaultsModuleDidDismiss(module: DefaultsModuleInput) { dismissals += 1 }
}

final class DefaultsUserSpy: RuuviUser {
    var apiKey: String? = "test-token"
    var email: String?
    var isAuthorized = false
    func login(apiKey: String) { self.apiKey = apiKey; isAuthorized = true }
    func logout() { apiKey = nil; isAuthorized = false }
}
