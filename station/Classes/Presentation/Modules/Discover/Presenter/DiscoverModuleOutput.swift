import Foundation
import BTKit

protocol DiscoverModuleOutput: class {
    func discover(module: DiscoverModuleInput, didAddNetworkTag mac: String)
    func discover(module: DiscoverModuleInput, didAddWebTag location: Location)
    func discover(module: DiscoverModuleInput, didAddWebTag provider: WeatherProvider)
    func discover(module: DiscoverModuleInput, didAdd ruuviTag: RuuviTag)
}
