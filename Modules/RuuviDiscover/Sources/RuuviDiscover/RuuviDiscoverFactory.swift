import BTKit
import Foundation
import RuuviContext
import RuuviCore
import RuuviFirmware
import RuuviLocal
import RuuviPresenters
import RuuviReactor
import RuuviService

public struct RuuviDiscoverDependencies {
    var errorPresenter: ErrorPresenter
    var activityPresenter: ActivityPresenter
    var permissionsManager: RuuviCorePermission
    var permissionPresenter: PermissionPresenter
    var foreground: BTForeground
    var ruuviReactor: RuuviReactor
    var ruuviOwnershipService: RuuviServiceOwnership
    var firmwareBuilder: RuuviFirmwareBuilder

    public init(
        errorPresenter: ErrorPresenter,
        activityPresenter: ActivityPresenter,
        permissionsManager: RuuviCorePermission,
        permissionPresenter: PermissionPresenter,
        foreground: BTForeground,
        ruuviReactor: RuuviReactor,
        ruuviOwnershipService: RuuviServiceOwnership,
        firmwareBuilder: RuuviFirmwareBuilder
    ) {
        self.errorPresenter = errorPresenter
        self.activityPresenter = activityPresenter
        self.permissionsManager = permissionsManager
        self.permissionPresenter = permissionPresenter
        self.foreground = foreground
        self.ruuviReactor = ruuviReactor
        self.ruuviOwnershipService = ruuviOwnershipService
        self.firmwareBuilder = firmwareBuilder
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
        presenter.firmwareBuilder = dependencies.firmwareBuilder
        return presenter
    }
}
