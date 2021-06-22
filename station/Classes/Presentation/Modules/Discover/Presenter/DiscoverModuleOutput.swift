import Foundation
import BTKit
import RuuviOntology
import RuuviVirtual

protocol DiscoverModuleOutput: AnyObject {
    func discover(module: DiscoverModuleInput, didAddNetworkTag mac: String)
    func discover(module: DiscoverModuleInput, didAddWebTag location: Location)
    func discover(module: DiscoverModuleInput, didAddWebTag provider: VirtualProvider)
    func discover(module: DiscoverModuleInput, didAdd ruuviTag: RuuviTag)
}
