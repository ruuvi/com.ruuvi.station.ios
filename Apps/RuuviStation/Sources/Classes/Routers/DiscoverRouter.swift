import BTKit
import Foundation
import RuuviDiscover
import RuuviOntology
import UIKit

protocol DiscoverRouterDelegate: AnyObject {
    func discoverRouterWantsClose(_ router: DiscoverRouter)
    func discoverRouterWantsCloseWithRuuviTagNavigation(
        _ router: DiscoverRouter,
        ruuviTag: RuuviTagSensor
    )
}

final class DiscoverRouter {
    var viewController: UIViewController {
        self.discover.viewController
    }

    weak var delegate: DiscoverRouterDelegate?

    // modules
    private var discover: RuuviDiscover {
        if let discover = weakDiscover {
            return discover
        } else {
            let r = AppAssembly.shared.assembler.resolver
            let discover = r.resolve(RuuviDiscover.self)!
            discover.router = self
            discover.output = self
            weakDiscover = discover
            return discover
        }
    }

    private weak var weakDiscover: RuuviDiscover?
}

extension DiscoverRouter: RuuviDiscoverOutput {
    func ruuviDiscoverWantsClose(_: RuuviDiscover) {
        delegate?.discoverRouterWantsClose(self)
    }

    func ruuvi(discover _: RuuviDiscover, didAdd _: AnyRuuviTagSensor) {
        delegate?.discoverRouterWantsClose(self)
    }

    func ruuvi(discover _: RuuviDiscover, didSelectFromNFC ruuviTag: RuuviTagSensor) {
        delegate?.discoverRouterWantsCloseWithRuuviTagNavigation(self, ruuviTag: ruuviTag)
    }
}
