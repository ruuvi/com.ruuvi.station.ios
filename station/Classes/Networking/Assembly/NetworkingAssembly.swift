import Foundation
import Swinject
import SwinjectPropertyLoader
import RuuviCloud
import RuuviUser
import RuuviVirtual
#if canImport(RuuviCloudPure)
import RuuviCloudPure
#endif
#if canImport(RuuviVirtualOWM)
import RuuviVirtualOWM
#endif

class NetworkingAssembly: Assembly {
    func assemble(container: Container) {
        let config = PlistPropertyLoader(bundle: .main, name: "Networking")
        try! container.applyPropertyLoader(config)

        container.register(OpenWeatherMapAPI.self) { r in
            let apiKey: String = r.property("Open Weather Map API Key")!
            let api = OpenWeatherMapAPIURLSession(apiKey: apiKey)
            return api
        }

        container.register(RuuviCloud.self) { r in
            let user = r.resolve(RuuviUser.self)!
            let baseUrlString: String = r.property("Ruuvi Cloud URL")!
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
    }
}
