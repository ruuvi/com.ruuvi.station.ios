import Swinject
import SwinjectPropertyLoader
import RuuviCloud
import RuuviUser

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
            let user = r.resolve(RuuviUser.self)!
            let apiKey = user.apiKey
            let baseUrlString: String = r.property("Ruuvi Cloud URL")!
            let baseUrl = URL(string: baseUrlString)!
            let cloud = r.resolve(RuuviCloudFactory.self)!.create(baseUrl: baseUrl, apiKey: apiKey)
            return cloud
        }

        container.register(RuuviCloudFactory.self) { _ in
            return RuuviCloudFactoryPure()
        }
    }
}
