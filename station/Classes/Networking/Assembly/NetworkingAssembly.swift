import Swinject
import SwinjectPropertyLoader

class NetworkingAssembly: Assembly {
    func assemble(container: Container) {
        let config = PlistPropertyLoader(bundle: .main, name: "Networking")
        try! container.applyPropertyLoader(config)

        container.register(OpenWeatherMapAPI.self) { r in
            let api = OpenWeatherMapAPIURLSession()
            api.apiKey = r.property("Open Weather Map API Key")!
            return api
        }

        container.register(RuuviNetworkFactory.self) { r in
            let factory = RuuviNetworkFactory()
            factory.kaltiot = r.resolve(RuuviNetworkKaltiot.self)
            factory.whereOS = r.resolve(RuuviNetworkWhereOS.self)
            return factory
        }.inObjectScope(.container)

        container.register(RuuviNetworkKaltiot.self) { r in
            let network = RuuviNetworkKaltiotURLSession()
            network.keychainService = r.resolve(KeychainService.self)
            return network
        }.inObjectScope(.container)

        container.register(RuuviNetworkWhereOS.self) { _ in
            return RuuviNetworkWhereOSURLSession()
        }.inObjectScope(.container)
    }
}
