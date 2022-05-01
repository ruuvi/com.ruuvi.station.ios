import Swinject
import RuuviCloud
import RuuviUser

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

        container.register(RuuviCloud.self) { r in
            let user = r.resolve(RuuviUser.self)!
            let baseUrlString: String = "https://network.ruuvi.com"
            let baseUrl = URL(string: baseUrlString)!
            let cloud = r.resolve(RuuviCloudFactory.self)!.create(
                baseUrl: baseUrl,
                user: user
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
