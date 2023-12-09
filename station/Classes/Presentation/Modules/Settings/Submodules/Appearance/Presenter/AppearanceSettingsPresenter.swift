import Foundation
import UIKit
import RuuviOntology
import RuuviLocal
import RuuviLocalization

class AppearanceSettingsPresenter: NSObject, AppearanceSettingsModuleInput {
    weak var view: AppearanceSettingsViewInput?
    var router: AppearanceSettingsRouterInput!

    var settings: RuuviLocalSettings!

    private var themeToken: NSObjectProtocol?

    deinit {
        themeToken?.invalidate()
    }
}

extension AppearanceSettingsPresenter: AppearanceSettingsViewOutput {
    func viewDidLoad() {
        configure()
        startObservingThemeSetting()
    }

    func viewDidTriggerViewModel(viewModel: AppearanceSettingsViewModel) {
        router.openSelection(with: viewModel)
    }
}

extension AppearanceSettingsPresenter {
    fileprivate func configure() {
        if let view = view {
            view.viewModels = [appThemeSetting()]
        }
    }

    fileprivate func appThemeSetting() -> AppearanceSettingsViewModel {
        let title = RuuviLocalization.appTheme
        let selectionItems: [RuuviTheme] = [
            .system,
            .dark,
            .light
        ]
        let selectedTheme: RuuviTheme = settings.theme

        let viewModel = AppearanceSettingsViewModel(
            title: title,
            items: selectionItems,
            selection: selectedTheme,
            type: .theme
        )
        return viewModel
    }

    private func startObservingThemeSetting() {
        themeToken = NotificationCenter
            .default
            .addObserver(forName: .AppearanceSettingsDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (_) in
                self?.configure()
                self?.updateTheme()
            })
    }

    private func updateTheme() {
        UIView.animate(withDuration: 0.3,
                       delay: 0.0,
                       options: .curveLinear,
                       animations: { [weak self] in
            guard let sSelf = self else { return }
            UIWindow.key?.overrideUserInterfaceStyle =
                sSelf.settings.theme.uiInterfaceStyle
        })
    }
}
