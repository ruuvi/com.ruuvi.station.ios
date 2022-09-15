import Foundation
import BTKit
import RuuviContext
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviCore
import RuuviPresenters

public struct RuuviDiscoverDependencies {
    var errorPresenter: ErrorPresenter
    var activityPresenter: ActivityPresenter
    var permissionsManager: RuuviCorePermission
    var permissionPresenter: PermissionPresenter
    var foreground: BTForeground
    var ruuviReactor: RuuviReactor
    var ruuviOwnershipService: RuuviServiceOwnership

    public init(
        errorPresenter: ErrorPresenter,
        activityPresenter: ActivityPresenter,
        permissionsManager: RuuviCorePermission,
        permissionPresenter: PermissionPresenter,
        foreground: BTForeground,
        ruuviReactor: RuuviReactor,
        ruuviOwnershipService: RuuviServiceOwnership
    ) {
        self.errorPresenter = errorPresenter
        self.activityPresenter = activityPresenter
        self.permissionsManager = permissionsManager
        self.permissionPresenter = permissionPresenter
        self.foreground = foreground
        self.ruuviReactor = ruuviReactor
        self.ruuviOwnershipService = ruuviOwnershipService
    }
}

public final class RuuviDiscoverFactory {
    public init() {}

    public func create(dependencies: RuuviDiscoverDependencies) -> RuuviDiscover {
        let presenter = DiscoverPresenter()
        presenter.errorPresenter = dependencies.errorPresenter
        presenter.activityPresenter = dependencies.activityPresenter
        presenter.permissionsManager = dependencies.permissionsManager
        presenter.permissionPresenter = dependencies.permissionPresenter
        presenter.foreground = dependencies.foreground
        presenter.ruuviReactor = dependencies.ruuviReactor
        presenter.ruuviOwnershipService = dependencies.ruuviOwnershipService
        return presenter
    }
}
