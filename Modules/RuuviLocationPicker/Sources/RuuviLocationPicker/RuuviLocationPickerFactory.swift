import Foundation
import RuuviPresenters
import RuuviCore
import RuuviLocation

public struct RuuviLocationPickerDependencies {
    let locationService: RuuviLocationService
    let activityPresenter: ActivityPresenter
    let errorPresenter: ErrorPresenter
    let permissionsManager: RuuviCorePermission
    let permissionPresenter: PermissionPresenter
    let locationManager: RuuviCoreLocation

    public init(
        locationService: RuuviLocationService,
        activityPresenter: ActivityPresenter,
        errorPresenter: ErrorPresenter,
        permissionsManager: RuuviCorePermission,
        permissionPresenter: PermissionPresenter,
        locationManager: RuuviCoreLocation
    ) {
        self.locationService = locationService
        self.activityPresenter = activityPresenter
        self.errorPresenter = errorPresenter
        self.permissionsManager = permissionsManager
        self.permissionPresenter = permissionPresenter
        self.locationManager = locationManager
    }
}

public final class RuuviLocationPickerFactory {
    public init() {}

    public func create(dependencies: RuuviLocationPickerDependencies) -> RuuviLocationPicker {
        let presenter = LocationPickerPresenter()
        presenter.locationService = dependencies.locationService
        presenter.activityPresenter = dependencies.activityPresenter
        presenter.errorPresenter = dependencies.errorPresenter
        presenter.permissionsManager = dependencies.permissionsManager
        presenter.permissionPresenter = dependencies.permissionPresenter
        presenter.locationManager = dependencies.locationManager
        return presenter
    }
}
