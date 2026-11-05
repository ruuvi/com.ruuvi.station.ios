import RuuviLocal
import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class AppearancePresenterTests: XCTestCase {
    func testEveryThemeIsSelectableAndRetainsThePickersTitleAndChoices() throws {
        let presenter = ASSelectionPresenter()
        let view = AppearanceSelectionViewSpy()
        let settings = AppTestSettings()
        presenter.view = view
        presenter.settings = settings
        presenter.viewDidLoad()
        presenter.viewDidSelectItem(item: RuuviTheme.dark, type: .theme)
        XCTAssertNil(view.viewModel)
        let model = AppearanceSettingsViewModel(
            title: "Theme", items: [RuuviTheme.system, .dark, .light],
            selection: RuuviTheme.system, type: .theme)
        presenter.configure(viewModel: model)
        for theme in [RuuviTheme.system, .dark, .light] {
            presenter.viewDidSelectItem(item: theme, type: .theme)
            XCTAssertEqual(settings.theme, theme)
            let selected = try XCTUnwrap(view.viewModel)
            XCTAssertEqual(selected.selection as? RuuviTheme, theme)
            XCTAssertEqual(selected.title, "Theme")
            XCTAssertEqual(selected.items.compactMap { $0 as? RuuviTheme }, [.system, .dark, .light])
        }
        presenter.viewDidSelectItem(item: TemperatureUnit.celsius, type: .theme)
        XCTAssertEqual(settings.theme, .light)
        XCTAssertEqual(view.viewModel?.selection as? RuuviTheme, .light)
    }

    func testAppearanceTracksExternalChangesAndRepeatedLoadsDoNotDuplicateObservers() throws {
        let notifications = NotificationCenter()
        var presenter: AppearanceSettingsPresenter? = AppearanceSettingsPresenter(notificationCenter: notifications)
        let view = AppearanceViewSpy()
        let settings = AppTestSettings()
        let router = AppearanceRouterSpy()
        presenter?.view = view
        presenter?.settings = settings
        presenter?.router = router
        presenter?.viewDidLoad()
        presenter?.viewDidLoad()
        XCTAssertEqual(view.models.first?.title, RuuviLocalization.appTheme)
        XCTAssertEqual(view.models.first?.items.compactMap { $0 as? RuuviTheme }, [.system, .dark, .light])
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        for theme in [RuuviTheme.dark, .light, .system] {
            let updates = view.updates
            settings.theme = theme
            notifications.post(name: .AppearanceSettingsDidChange, object: nil)
            XCTAssertEqual(view.updates, updates + 1)
            XCTAssertEqual(view.models.first?.selection as? RuuviTheme, theme)
            XCTAssertEqual(window.overrideUserInterfaceStyle, theme.uiInterfaceStyle)
        }
        let model = try XCTUnwrap(view.models.first)
        presenter?.viewDidTriggerViewModel(viewModel: model)
        XCTAssertEqual(router.selected?.title, model.title)
        XCTAssertEqual(router.selected?.selection as? RuuviTheme, .system)
        weak var weakPresenter = presenter
        presenter = nil
        XCTAssertNil(weakPresenter)
        let updates = view.updates
        notifications.post(name: .AppearanceSettingsDidChange, object: nil)
        XCTAssertEqual(view.updates, updates)
    }
}

private final class AppearanceSelectionViewSpy: ASSelectionViewInput {
    var viewModel: AppearanceSettingsViewModel?
}
private final class AppearanceViewSpy: AppearanceSettingsViewInput {
    var models = [AppearanceSettingsViewModel]()
    var updates = 0
    var viewModels: [AppearanceSettingsViewModel] {
        get { models }
        set { models = newValue; updates += 1 }
    }
}
private final class AppearanceRouterSpy: AppearanceSettingsRouterInput {
    var selected: AppearanceSettingsViewModel?
    func dismiss() {}
    func openSelection(with viewModel: AppearanceSettingsViewModel) { selected = viewModel }
}
