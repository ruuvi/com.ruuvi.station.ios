import Foundation
import RuuviDiscover
import RuuviOntology
import BTKit
import RuuviLocationPicker

protocol DiscoverRouterDelegate: AnyObject {
    func discoverRouterWantsClose(_ router: DiscoverRouter)
}

final class DiscoverRouter {
    var viewController: UIViewController {
        return self.discover.viewController
    }
    weak var delegate: DiscoverRouterDelegate?

    // modules
    private var discover: RuuviDiscover {
        if let discover = self.weakDiscover {
            return discover
        } else {
            let r = AppAssembly.shared.assembler.resolver
            let discover = r.resolve(RuuviDiscover.self)!
            discover.router = self
            discover.output = self
            self.weakDiscover = discover
            return discover
        }
    }
    private weak var weakDiscover: RuuviDiscover?
}

extension DiscoverRouter: RuuviDiscoverOutput {
    func ruuviDiscoverWantsClose(_ ruuviDiscover: RuuviDiscover) {
        delegate?.discoverRouterWantsClose(self)
    }

    func ruuvi(discover: RuuviDiscover, didAdd ruuviTag: AnyRuuviTagSensor) {
        delegate?.discoverRouterWantsClose(self)
    }
}
