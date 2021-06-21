import UIKit
import RuuviCore
import RuuviLocation

class LocationPickerAppleConfigurator {
    func configure(view: LocationPickerAppleViewController) {
        let r = AppAssembly.shared.assembler.resolver

        let router = LocationPickerRouter()
        router.transitionHandler = view

        let presenter = LocationPickerPresenter()
        presenter.view = view
        presenter.router = router
        presenter.locationService = r.resolve(RuuviLocationService.self)
        presenter.activityPresenter = r.resolve(ActivityPresenter.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        presenter.permissionsManager = r.resolve(PermissionsManager.self)
        presenter.permissionPresenter = r.resolve(PermissionPresenter.self)
        presenter.locationManager = r.resolve(RuuviCoreLocation.self)

        view.output = presenter
    }
}
