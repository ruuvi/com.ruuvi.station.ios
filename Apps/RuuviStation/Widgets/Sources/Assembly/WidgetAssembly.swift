import Foundation
import RuuviCloud
import RuuviLocal
import RuuviUser
import Swinject

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
            let localIDs = r.resolve(RuuviLocalIDs.self)!
            let baseUrlString: String = useDevServer ?
                Constants.ruuviCloudBaseURLDev.rawValue : Constants.ruuviCloudBaseURL.rawValue
            let baseUrl = URL(string: baseUrlString)!
            let cloud = r.resolve(RuuviCloudFactory.self)!.create(
                baseUrl: baseUrl,
                user: user,
                pool: nil
            )
            return RuuviCloudCanonicalProxy(cloud: cloud, localIDs: localIDs)
        }

        container.register(RuuviCloudFactory.self) { _ in
            RuuviCloudFactoryPure()
        }

        container.register(RuuviUserFactory.self) { _ in
            RuuviUserFactoryCoordinator()
        }

        container.register(RuuviLocalFactory.self) { _ in
            RuuviLocalFactoryUserDefaults()
        }

        container.register(RuuviLocalIDs.self) { r in
            let factory = r.resolve(RuuviLocalFactory.self)!
            return factory.createLocalIDs()
        }.inObjectScope(.container)

        container.register(RuuviUser.self) { r in
            let factory = r.resolve(RuuviUserFactory.self)!
            return factory.createUser()
        }.inObjectScope(.container)
    }
}
