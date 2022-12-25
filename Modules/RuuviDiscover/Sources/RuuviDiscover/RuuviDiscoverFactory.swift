import Foundation
import BTKit
import RuuviContext
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviVirtual
import RuuviCore
import RuuviPresenters

public struct RuuviDiscoverDependencies {
    var virtualReactor: VirtualReactor
    var errorPresenter: ErrorPresenter
    var activityPresenter: ActivityPresenter
    var virtualService: VirtualService
    var permissionsManager: RuuviCorePermission
    var permissionPresenter: PermissionPresenter
    var foreground: BTForeground
    var ruuviReactor: RuuviReactor
    var ruuviOwnershipService: RuuviServiceOwnership

    public init(
        virtualReactor: VirtualReactor,
        errorPresenter: ErrorPresenter,
        activityPresenter: ActivityPresenter,
        virtualService: VirtualService,
        permissionsManager: RuuviCorePermission,
        permissionPresenter: PermissionPresenter,
        foreground: BTForeground,
        ruuviReactor: RuuviReactor,
        ruuviOwnershipService: RuuviServiceOwnership
    ) {
        self.virtualReactor = virtualReactor
        self.errorPresenter = errorPresenter
        self.activityPresenter = activityPresenter
        self.virtualService = virtualService
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
        presenter.virtualReactor = dependencies.virtualReactor
        presenter.errorPresenter = dependencies.errorPresenter
        presenter.activityPresenter = dependencies.activityPresenter
        presenter.virtualService = dependencies.virtualService
        presenter.permissionsManager = dependencies.permissionsManager
        presenter.permissionPresenter = dependencies.permissionPresenter
        presenter.foreground = dependencies.foreground
        presenter.ruuviReactor = dependencies.ruuviReactor
        presenter.ruuviOwnershipService = dependencies.ruuviOwnershipService
        return presenter
    }
}
