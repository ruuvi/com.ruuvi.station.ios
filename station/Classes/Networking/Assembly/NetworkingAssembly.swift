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
            factory.userApi = r.resolve(RuuviNetworkUserApi.self)
            return factory
        }.inObjectScope(.container)

        container.register(RuuviNetworkUserApi.self) { r in
            let service = RuuviNetworkUserApiURLSession()
            service.keychainService = r.resolve(KeychainService.self)
            return service
        }
    }
}
