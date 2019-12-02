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
    }
}
