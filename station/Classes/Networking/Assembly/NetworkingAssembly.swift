import Swinject
import SwinjectPropertyLoader
import RuuviCloud

class NetworkingAssembly: Assembly {
    func assemble(container: Container) {
        let config = PlistPropertyLoader(bundle: .main, name: "Networking")
        try! container.applyPropertyLoader(config)

        container.register(OpenWeatherMapAPI.self) { r in
            let api = OpenWeatherMapAPIURLSession()
            api.apiKey = r.property("Open Weather Map API Key")!
            return api
        }

        container.register(RuuviCloud.self) { r in
            let keychain = r.resolve(KeychainService.self)
            let apiKey = keychain?.ruuviUserApiKey
            let baseUrlString: String = r.property("Ruuvi Cloud URL")!
            let baseUrl = URL(string: baseUrlString)!
            let cloud = r.resolve(RuuviCloudFactory.self)!.create(baseUrl: baseUrl, apiKey: apiKey)
            return cloud
        }.inObjectScope(.container)

        container.register(RuuviCloudFactory.self) { _ in
            return RuuviCloudFactoryPure()
        }

        container.register(RuuviNetworkUserApi.self) { r in
            let service = RuuviNetworkUserApiURLSession()
            service.keychainService = r.resolve(KeychainService.self)
            return service
        }
    }
}
