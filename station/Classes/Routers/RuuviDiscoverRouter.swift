import Foundation
import RuuviDiscover
import RuuviOntology
import BTKit

protocol RuuviDiscoverRouterDelegate: AnyObject {
    func discoverRouterWantsClose(_ router: RuuviDiscoverRouter)
}

final class RuuviDiscoverRouter {
    var viewController: UIViewController {
        return self.discover.viewController
    }
    weak var delegate: RuuviDiscoverRouterDelegate?

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

extension RuuviDiscoverRouter: RuuviDiscoverOutput {
    func ruuviDiscoverWantsBuySensors(_ ruuviDiscover: RuuviDiscover) {
        UIApplication.shared.open(URL(string: "https://ruuvi.com")!, options: [:], completionHandler: nil)
    }

    func ruuviDiscoverWantsClose(_ ruuviDiscover: RuuviDiscover) {
        delegate?.discoverRouterWantsClose(self)
    }

    func ruuvi(discover: RuuviDiscover, didAdd virtualSensor: AnyVirtualTagSensor) {
        delegate?.discoverRouterWantsClose(self)
    }

    func ruuvi(discover: RuuviDiscover, didAdd ruuviTag: AnyRuuviTagSensor) {
        delegate?.discoverRouterWantsClose(self)
    }
}
