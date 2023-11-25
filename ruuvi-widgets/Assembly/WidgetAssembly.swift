import Foundation
import Swinject
import RuuviCloud
import RuuviUser
#if canImport(RuuviCloudPure)
import RuuviCloudPure
#endif
#if canImport(RuuviUserCoordinator)
import RuuviUserCoordinator
#endif

final class WidgetAssembly {
    static let shared = WidgetAssembly()
    var assembler: Assembler

    init() {
        assembler = Assembler(
            [
                NetworkingAssembly()
            ])
    }
}

private final class NetworkingAssembly: Assembly {
    func assemble(container: Container) {

        let appGroupDefaults = UserDefaults(
            suiteName: Constants.appGroupBundleId.rawValue
        )
        let useDevServer = appGroupDefaults?.bool(
            forKey: Constants.useDevServerKey.rawValue
        ) ?? false

        container.register(RuuviCloud.self) { r in
            let user = r.resolve(RuuviUser.self)!
            let baseUrlString: String = useDevServer ?
                Constants.ruuviCloudBaseURLDev.rawValue : Constants.ruuviCloudBaseURL.rawValue
            let baseUrl = URL(string: baseUrlString)!
            let cloud = r.resolve(RuuviCloudFactory.self)!.create(
                baseUrl: baseUrl,
                user: user,
                pool: nil
            )
            return cloud
        }

        container.register(RuuviCloudFactory.self) { _ in
            return RuuviCloudFactoryPure()
        }

        container.register(RuuviUserFactory.self) { _ in
            return RuuviUserFactoryCoordinator()
        }

        container.register(RuuviUser.self) { r in
            let factory = r.resolve(RuuviUserFactory.self)!
            return factory.createUser()
        }.inObjectScope(.container)

    }
}
