import Swinject
import SwinjectPropertyLoader

class PresentationAssembly: Assembly {
    func assemble(container: Container) {

        let config = PlistPropertyLoader(bundle: .main, name: "Presentation")
        try! container.applyPropertyLoader(config)

        container.register(ActivityPresenter.self) { _ in
            let presenter = ActivityPresenterRuuviLogo()
            return presenter
        }

        container.register(AlertPresenter.self) { _ in
            let presenter = AlertPresenterImpl()
            return presenter
        }

        container.register(ErrorPresenter.self) { _ in
            let presenter = ErrorPresenterAlert()
            return presenter
        }

        container.register(FLEXFeatureTogglesViewController.self) { r in
            let controller = FLEXFeatureTogglesViewController()
            controller.featureToggleService = r.resolve(FeatureToggleService.self)
            return controller
        }

        container.register(MailComposerPresenter.self) { r in
            let presenter = MailComposerPresenterMessageUI()
            presenter.errorPresenter = r.resolve(ErrorPresenter.self)
            return presenter
        }

        container.register(PermissionPresenter.self) { _ in
            let presenter = PermissionPresenterAlert()
            return presenter
        }

        container.register(PhotoPickerPresenter.self) { r in
            let presenter = PhotoPickerPresenterSheet()
            presenter.permissionsManager = r.resolve(PermissionsManager.self)
            presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
            return presenter
        }

        container.register(DfuFilePickerPresenter.self) { r in
            let presenter = DfuFilePickerPresenterSheet()
            presenter.permissionsManager = r.resolve(PermissionsManager.self)
            presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
            return presenter
        }
    }
}
