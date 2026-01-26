import BTKit
import Foundation
import RuuviContext
import RuuviCore
import RuuviDaemon
import RuuviDFU
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
    var background: BTBackground
    var propertiesDaemon: RuuviTagPropertiesDaemon
    var ruuviDFU: RuuviDFU
    var ruuviReactor: RuuviReactor
    var ruuviOwnershipService: RuuviServiceOwnership
    var firmwareBuilder: RuuviFirmwareBuilder

    public init(
        errorPresenter: ErrorPresenter,
        activityPresenter: ActivityPresenter,
        permissionsManager: RuuviCorePermission,
        permissionPresenter: PermissionPresenter,
        foreground: BTForeground,
        background: BTBackground,
        propertiesDaemon: RuuviTagPropertiesDaemon,
        ruuviDFU: RuuviDFU,
        ruuviReactor: RuuviReactor,
        ruuviOwnershipService: RuuviServiceOwnership,
        firmwareBuilder: RuuviFirmwareBuilder
    ) {
        self.errorPresenter = errorPresenter
        self.activityPresenter = activityPresenter
        self.permissionsManager = permissionsManager
        self.permissionPresenter = permissionPresenter
        self.foreground = foreground
        self.background = background
        self.propertiesDaemon = propertiesDaemon
        self.ruuviDFU = ruuviDFU
        self.ruuviReactor = ruuviReactor
        self.ruuviOwnershipService = ruuviOwnershipService
        self.firmwareBuilder = firmwareBuilder
    }
}

public final class RuuviDiscoverFactory {
    public init() {}

    public func create(dependencies: RuuviDiscoverDependencies) -> RuuviDiscover {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                buildPresenter(dependencies: dependencies)
            }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated {
                buildPresenter(dependencies: dependencies)
            }
        }
    }

    @MainActor
    private func buildPresenter(dependencies: RuuviDiscoverDependencies) -> RuuviDiscover {
        let presenter = DiscoverPresenter()
        presenter.errorPresenter = dependencies.errorPresenter
        presenter.activityPresenter = dependencies.activityPresenter
        presenter.permissionsManager = dependencies.permissionsManager
        presenter.permissionPresenter = dependencies.permissionPresenter
        presenter.foreground = dependencies.foreground
        presenter.background = dependencies.background
        presenter.propertiesDaemon = dependencies.propertiesDaemon
        presenter.ruuviDFU = dependencies.ruuviDFU
        presenter.ruuviReactor = dependencies.ruuviReactor
        presenter.ruuviOwnershipService = dependencies.ruuviOwnershipService
        presenter.firmwareBuilder = dependencies.firmwareBuilder
        return presenter
    }
}
