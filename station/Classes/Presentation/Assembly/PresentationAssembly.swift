import Swinject

class PresentationAssembly: Assembly {
    func assemble(container: Container) {
        
        container.register(ActivityPresenter.self) { r in
            let presenter = ActivityPresenterRuuviLogo()
            return presenter
        }
        
        container.register(ErrorPresenter.self) { r in
            let presenter = ErrorPresenterAlert()
            return presenter
        }
        
        container.register(PermissionPresenter.self) { r in
            let presenter = PermissionPresenterAlert()
            return presenter
        }
        
        container.register(PhotoPickerPresenter.self) { r in
            let presenter = PhotoPickerPresenterSheet()
            presenter.permissionsManager = r.resolve(PermissionsManager.self)
            presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
            return presenter
        }
    }
}
